package com.nornenjs.web;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class ControllerAspect {

	private static Boolean isRunServer = false;
	
	private final Logger logger = LoggerFactory.getLogger(ControllerAspect.class);

	@Around("bean(*Controller)")
	public Object trace(ProceedingJoinPoint joinPoint) throws Throwable {
		String signatureString = joinPoint.getSignature().toShortString();
		logger.info("Start time " + signatureString );
		long start = System.currentTimeMillis();

		try {
			
			return joinPoint.proceed();
		} finally {
			long finish = System.currentTimeMillis();
			logger.info("End time " + signatureString);
			logger.info("Run time " + signatureString + " " + (finish - start) + "ms");
		}
	}

}
