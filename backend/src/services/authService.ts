import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../utils/database';
import config from '../config';
import { UnauthorizedError, ConflictError, BadRequestError } from '../utils/errors';
import validator from 'validator';

export interface RegisterData {
  email: string;
  password: string;
  name?: string;
}

export interface LoginData {
  email: string;
  password: string;
}

export interface TokenPayload {
  id: string;
  email: string;
}

export class AuthService {
  /**
   * Register a new user
   */
  async register(data: RegisterData) {
    const { email, password, name } = data;

    // Validate email
    if (!validator.isEmail(email)) {
      throw new BadRequestError('Invalid email address');
    }

    // Validate password strength
    if (password.length < 8) {
      throw new BadRequestError('Password must be at least 8 characters long');
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });

    if (existingUser) {
      throw new ConflictError('User with this email already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, config.BCRYPT_ROUNDS);

    // Create user
    const user = await prisma.user.create({
      data: {
        email: email.toLowerCase(),
        password: hashedPassword,
        name,
      },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
      },
    });

    // Generate tokens
    const accessToken = this.generateAccessToken({ id: user.id, email: user.email });
    const refreshToken = this.generateRefreshToken({ id: user.id, email: user.email });

    return {
      user,
      accessToken,
      refreshToken,
    };
  }

  /**
   * Login user
   */
  async login(data: LoginData) {
    const { email, password } = data;

    // Find user
    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: {
        wallets: {
          select: {
            walletAddress: true,
            isPrimary: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Generate tokens
    const accessToken = this.generateAccessToken({ id: user.id, email: user.email });
    const refreshToken = this.generateRefreshToken({ id: user.id, email: user.email });

    const { password: _, ...userWithoutPassword } = user;

    return {
      user: userWithoutPassword,
      accessToken,
      refreshToken,
    };
  }

  /**
   * Link wallet to user account
   */
  async linkWallet(userId: string, walletAddress: string) {
    // Validate Ethereum address
    if (!/^0x[a-fA-F0-9]{40}$/.test(walletAddress)) {
      throw new BadRequestError('Invalid Ethereum address');
    }

    // Check if wallet is already linked to this user
    const existingLink = await prisma.userWallet.findUnique({
      where: {
        userId_walletAddress: {
          userId,
          walletAddress: walletAddress.toLowerCase(),
        },
      },
    });

    if (existingLink) {
      throw new ConflictError('Wallet already linked to your account');
    }

    // Check if wallet is linked to another user
    const walletLinkedToOther = await prisma.userWallet.findFirst({
      where: {
        walletAddress: walletAddress.toLowerCase(),
        userId: { not: userId },
      },
    });

    if (walletLinkedToOther) {
      throw new ConflictError('Wallet is already linked to another account');
    }

    // Check if user has any wallets (to set as primary)
    const userWalletsCount = await prisma.userWallet.count({
      where: { userId },
    });

    // Link wallet
    const wallet = await prisma.userWallet.create({
      data: {
        userId,
        walletAddress: walletAddress.toLowerCase(),
        isPrimary: userWalletsCount === 0, // First wallet is primary
      },
    });

    return wallet;
  }

  /**
   * Unlink wallet from user account
   */
  async unlinkWallet(userId: string, walletAddress: string) {
    const wallet = await prisma.userWallet.findUnique({
      where: {
        userId_walletAddress: {
          userId,
          walletAddress: walletAddress.toLowerCase(),
        },
      },
    });

    if (!wallet) {
      throw new BadRequestError('Wallet not linked to your account');
    }

    // If this was the primary wallet, set another as primary
    if (wallet.isPrimary) {
      const otherWallet = await prisma.userWallet.findFirst({
        where: {
          userId,
          walletAddress: { not: walletAddress.toLowerCase() },
        },
      });

      if (otherWallet) {
        await prisma.userWallet.update({
          where: { id: otherWallet.id },
          data: { isPrimary: true },
        });
      }
    }

    await prisma.userWallet.delete({
      where: { id: wallet.id },
    });

    return { message: 'Wallet unlinked successfully' };
  }

  /**
   * Get user wallets
   */
  async getUserWallets(userId: string) {
    return await prisma.userWallet.findMany({
      where: { userId },
      orderBy: [{ isPrimary: 'desc' }, { linkedAt: 'asc' }],
    });
  }

  /**
   * Verify JWT token
   */
  verifyToken(token: string): TokenPayload {
    try {
      return jwt.verify(token, config.JWT_SECRET) as TokenPayload;
    } catch (error) {
      throw new UnauthorizedError('Invalid or expired token');
    }
  }

  /**
   * Generate access token
   */
  private generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(payload, config.JWT_SECRET, {
      expiresIn: config.JWT_EXPIRES_IN,
    });
  }

  /**
   * Generate refresh token
   */
  private generateRefreshToken(payload: TokenPayload): string {
    return jwt.sign(payload, config.JWT_SECRET, {
      expiresIn: config.JWT_REFRESH_EXPIRES_IN,
    });
  }

  /**
   * Refresh access token
   */
  async refreshAccessToken(refreshToken: string) {
    const payload = this.verifyToken(refreshToken);
    const accessToken = this.generateAccessToken({ id: payload.id, email: payload.email });
    return { accessToken };
  }
}

export default new AuthService();
