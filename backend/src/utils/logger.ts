import winston from 'winston';
import config from '../config';
import { existsSync, mkdirSync } from 'fs';
import { dirname } from 'path';

// Ensure logs directory exists
const logDir = dirname(config.LOG_FILE);
if (!existsSync(logDir)) {
  mkdirSync(logDir, { recursive: true });
}

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
    return `${timestamp} [${level}]: ${message} ${metaStr}`;
  })
);

const logger = winston.createLogger({
  level: config.LOG_LEVEL,
  format: logFormat,
  transports: [
    // Write all logs to file
    new winston.transports.File({ filename: config.LOG_FILE }),
    // Write errors to separate file
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    }),
  ],
});

// Add console transport in development
if (config.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: consoleFormat,
    })
  );
}

export default logger;
