package com.selimhorri.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.cloud.netflix.eureka.EnableEurekaClient;
import org.springframework.cloud.openfeign.EnableFeignClients;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

import com.selimhorri.app.feature.config.FeatureToggleProperties;

@SpringBootApplication
@EnableEurekaClient
@EnableFeignClients
@EnableAspectJAutoProxy
@EnableConfigurationProperties(FeatureToggleProperties.class)
@RefreshScope
public class ProxyClientApplication {
	
	public static void main(String[] args) {
		SpringApplication.run(ProxyClientApplication.class, args);
	}
	
	
	
}










