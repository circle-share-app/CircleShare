import { Request, Response, NextFunction } from 'express';
import { AppError } from '../../utils/errors';
import logger from '../../utils/logger';
import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';

export const errorHandler = (err: Error, req: Request, res: Response, next: NextFunction) => {
  logger.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // Handle AppError (our custom errors)
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        message: err.message,
        statusCode: err.statusCode,
      },
    });
  }

  // Handle Zod validation errors
  if (err instanceof ZodError) {
    return res.status(400).json({
      success: false,
      error: {
        message: 'Validation error',
        statusCode: 400,
        details: err.errors.map((e) => ({
          path: e.path.join('.'),
          message: e.message,
        })),
      },
    });
  }

  // Handle Prisma errors
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    // Unique constraint violation
    if (err.code === 'P2002') {
      return res.status(409).json({
        success: false,
        error: {
          message: 'Record already exists',
          statusCode: 409,
        },
      });
    }

    // Record not found
    if (err.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Record not found',
          statusCode: 404,
        },
      });
    }
  }

  // Handle ethers errors
  if (err.message.includes('could not detect network') || err.message.includes('RPC')) {
    return res.status(503).json({
      success: false,
      error: {
        message: 'Blockchain connection error',
        statusCode: 503,
      },
    });
  }

  // Default to 500 server error
  return res.status(500).json({
    success: false,
    error: {
      message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error',
      statusCode: 500,
    },
  });
};
