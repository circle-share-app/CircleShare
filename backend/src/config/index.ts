import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

// Environment variable schema validation
const envSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform(Number).default('3000'),
  API_PREFIX: z.string().default('/api'),

  // Database
  DATABASE_URL: z.string(),

  // Blockchain
  BLOCKCHAIN_NETWORK: z.string(),
  RPC_URL: z.string().url(),
  RPC_FALLBACK_URL: z.string().url().optional(),

  // Contracts
  CIRCLE_FACTORY_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/, 'Invalid Ethereum address'),
  CIRCLE_FACTORY_DEPLOYMENT_BLOCK: z.string().transform(Number),

  // Event Listener
  SYNC_BATCH_SIZE: z.string().transform(Number).default('1000'),
  SYNC_INTERVAL_MS: z.string().transform(Number).default('30000'),
  MAX_RETRY_ATTEMPTS: z.string().transform(Number).default('3'),
  RETRY_DELAY_MS: z.string().transform(Number).default('5000'),

  // JWT
  JWT_SECRET: z.string().min(32, 'JWT secret must be at least 32 characters'),
  JWT_EXPIRES_IN: z.string().default('7d'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('30d'),

  // Password
  BCRYPT_ROUNDS: z.string().transform(Number).default('12'),

  // Rate Limiting
  RATE_LIMIT_WINDOW_MS: z.string().transform(Number).default('900000'),
  RATE_LIMIT_MAX_REQUESTS: z.string().transform(Number).default('100'),

  // Logging
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  LOG_FILE: z.string().default('logs/app.log'),

  // CORS
  CORS_ORIGIN: z.string().default('*'),
});

// Parse and validate environment variables
const parseEnv = () => {
  try {
    return envSchema.parse(process.env);
  } catch (error) {
    if (error instanceof z.ZodError) {
      console.error('❌ Invalid environment variables:');
      error.errors.forEach((err) => {
        console.error(`  - ${err.path.join('.')}: ${err.message}`);
      });
      process.exit(1);
    }
    throw error;
  }
};

export const config = parseEnv();

export default config;
