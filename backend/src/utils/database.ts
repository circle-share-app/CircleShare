import { PrismaClient } from '@prisma/client';
import logger from './logger';

const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'event', level: 'error' },
    { emit: 'event', level: 'warn' },
  ],
});

// Log database queries in development
prisma.$on('query', (e: any) => {
  if (process.env.NODE_ENV === 'development') {
    logger.debug('Query: ' + e.query);
    logger.debug('Duration: ' + e.duration + 'ms');
  }
});

prisma.$on('error', (e: any) => {
  logger.error('Database Error:', e);
});

prisma.$on('warn', (e: any) => {
  logger.warn('Database Warning:', e);
});

export default prisma;
