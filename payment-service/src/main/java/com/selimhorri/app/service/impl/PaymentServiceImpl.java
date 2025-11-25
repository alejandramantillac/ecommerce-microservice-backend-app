package com.selimhorri.app.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import javax.transaction.Transactional;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.selimhorri.app.constant.AppConstant;
import com.selimhorri.app.domain.PaymentStatus;
import com.selimhorri.app.dto.OrderDto;
import com.selimhorri.app.dto.PaymentDto;
import com.selimhorri.app.exception.wrapper.PaymentNotFoundException;
import com.selimhorri.app.helper.PaymentMappingHelper;
import com.selimhorri.app.metrics.BusinessMetrics;
import com.selimhorri.app.repository.PaymentRepository;
import com.selimhorri.app.service.PaymentService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Transactional
@Slf4j
@RequiredArgsConstructor
public class PaymentServiceImpl implements PaymentService {
	
	private final PaymentRepository paymentRepository;
	private final RestTemplate restTemplate;
	private final BusinessMetrics businessMetrics;
	
	@Override
	public List<PaymentDto> findAll() {
		log.info("*** PaymentDto List, service; fetch all payments *");
		return this.paymentRepository.findAll()
				.stream()
					.map(PaymentMappingHelper::map)
					.map(p -> {
						p.setOrderDto(this.restTemplate.getForObject(AppConstant.DiscoveredDomainsApi
								.ORDER_SERVICE_API_URL + "/" + p.getOrderDto().getOrderId(), OrderDto.class));
						return p;
					})
					.distinct()
					.collect(Collectors.toUnmodifiableList());
	}
	
	@Override
	public PaymentDto findById(final Integer paymentId) {
		log.info("*** PaymentDto, service; fetch payment by id *");
		return this.paymentRepository.findById(paymentId)
				.map(PaymentMappingHelper::map)
				.map(p -> {
					p.setOrderDto(this.restTemplate.getForObject(AppConstant.DiscoveredDomainsApi
							.ORDER_SERVICE_API_URL + "/" + p.getOrderDto().getOrderId(), OrderDto.class));
					return p;
				})
				.orElseThrow(() -> new PaymentNotFoundException(String.format("Payment with id: %d not found", paymentId)));
	}
	
	@Override
	public PaymentDto save(final PaymentDto paymentDto) {
		log.info("*** PaymentDto, service; save payment *");
		PaymentDto savedPayment = PaymentMappingHelper.map(this.paymentRepository
				.save(PaymentMappingHelper.map(paymentDto)));
		
		// Record business metrics
		this.businessMetrics.recordPaymentProcessed(0.0); // Amount would come from order if available
		
		if (savedPayment.getPaymentStatus() == PaymentStatus.COMPLETED) {
			this.businessMetrics.recordPaymentSuccessful();
		} else if (savedPayment.getPaymentStatus() == PaymentStatus.NOT_STARTED) {
			this.businessMetrics.recordPaymentFailed();
		}
		
		return savedPayment;
	}
	
	@Override
	public PaymentDto update(final PaymentDto paymentDto) {
		log.info("*** PaymentDto, service; update payment *");
		PaymentDto updatedPayment = PaymentMappingHelper.map(this.paymentRepository
				.save(PaymentMappingHelper.map(paymentDto)));
		
		// Record business metrics for status changes
		if (updatedPayment.getPaymentStatus() == PaymentStatus.COMPLETED) {
			this.businessMetrics.recordPaymentSuccessful();
		} else if (updatedPayment.getPaymentStatus() == PaymentStatus.NOT_STARTED) {
			this.businessMetrics.recordPaymentFailed();
		}
		
		return updatedPayment;
	}
	
	@Override
	public void deleteById(final Integer paymentId) {
		log.info("*** Void, service; delete payment by id *");
		this.paymentRepository.deleteById(paymentId);
	}
	
	
	
}









