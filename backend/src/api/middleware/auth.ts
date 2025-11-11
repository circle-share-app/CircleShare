import { Request, Response, NextFunction } from 'express';
import authService from '../../services/authService';
import { UnauthorizedError } from '../../utils/errors';
import prisma from '../../utils/database';

/**
 * Middleware to authenticate requests using JWT
 */
export const authenticate = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('No token provided');
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const payload = authService.verifyToken(token);

    // Get user wallets
    const wallets = await prisma.userWallet.findMany({
      where: { userId: payload.id },
      select: { walletAddress: true },
    });

    // Attach user info to request
    req.user = {
      id: payload.id,
      email: payload.email,
      wallets: wallets.map((w) => w.walletAddress),
    };

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Optional authentication - doesn't fail if no token
 */
export const optionalAuth = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const payload = authService.verifyToken(token);

      const wallets = await prisma.userWallet.findMany({
        where: { userId: payload.id },
        select: { walletAddress: true },
      });

      req.user = {
        id: payload.id,
        email: payload.email,
        wallets: wallets.map((w) => w.walletAddress),
      };
    }
    next();
  } catch (error) {
    // Continue without authentication
    next();
  }
};
