package com.brianrepro.pong.config;

import org.apache.activemq.artemis.api.core.client.ActiveMQClient;
import org.apache.activemq.artemis.api.core.client.ServerLocator;
import org.apache.activemq.artemis.jms.client.ActiveMQConnectionFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.support.converter.MappingJackson2MessageConverter;
import org.springframework.jms.support.converter.MessageConverter;
import org.springframework.jms.support.converter.MessageType;
import io.vavr.control.Try;
import javax.jms.ConnectionFactory;

@Configuration
@EnableJms
public class ArtemisMQConfig {

    @Value("${app.artemis.queue.ping}")
    private String pingQueue;

    @Value("${app.artemis.queue.pong}")
    private String pongQueue;

    @Value("${mq.host}")
    private String mqHost;

    @Value("${mq.port}")
    private int mqPort;

    @Value("${mq.user}")
    private String mqUser;

    @Value("${mq.pass}")
    private String mqPass;

    @Bean
    public ServerLocator serverLocator() {
        try {
            return Try.of(() -> ActiveMQClient.createServerLocator("tcp://" + mqHost + ":" + mqPort))
            .map(locator -> {
                locator.setReconnectAttempts(3);
                locator.setRetryInterval(5000);
                locator.setRetryIntervalMultiplier(2);
                return locator;
            }).get();
            //return ActiveMQClient.createServerLocator("tcp://" + mqHost + ":" + mqPort);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create Artemis server locator", e);
        }
    }

    @Bean
    public ConnectionFactory connectionFactory(ServerLocator serverLocator) {
        try {
            ActiveMQConnectionFactory connectionFactory = new ActiveMQConnectionFactory(serverLocator);
            connectionFactory.setUser(mqUser);
            connectionFactory.setPassword(mqPass);
            return connectionFactory;
        } catch (Exception e) {
            throw new RuntimeException("Failed to create Artemis connection factory", e);
        }
    }

    @Bean
    public MessageConverter jacksonJmsMessageConverter() {
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter() {
            @Override
            public javax.jms.Message toMessage(Object object, javax.jms.Session session) throws javax.jms.JMSException {
                javax.jms.Message message = super.toMessage(object, session);
                // Always set the type ID to "ChatMessage" for cross-service compatibility
                message.setStringProperty("_type", "ChatMessage");
                return message;
            }
            
            @Override
            public Object fromMessage(javax.jms.Message message) throws javax.jms.JMSException {
                // Create a new message with the correct type ID for deserialization
                if (message instanceof javax.jms.TextMessage) {
                    javax.jms.TextMessage textMessage = (javax.jms.TextMessage) message;
                    String text = textMessage.getText();
                    
                    // Parse the JSON and create a ChatMessage object directly
                    try {
                        com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                        return mapper.readValue(text, com.brianrepro.pong.model.ChatMessage.class);
                    } catch (Exception e) {
                        throw new javax.jms.JMSException("Failed to parse message: " + e.getMessage());
                    }
                }
                return super.fromMessage(message);
            }
        };
        converter.setTargetType(MessageType.TEXT);
        converter.setTypeIdPropertyName("_type");
        return converter;
    }

    @Bean
    public JmsTemplate jmsTemplate(ConnectionFactory connectionFactory) {
        JmsTemplate template = new JmsTemplate();
        template.setConnectionFactory(connectionFactory);
        template.setMessageConverter(jacksonJmsMessageConverter());
        return template;
    }

    @Bean
    public DefaultJmsListenerContainerFactory jmsListenerContainerFactory(ConnectionFactory connectionFactory) {
        DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(jacksonJmsMessageConverter());
        factory.setConcurrency("1-1");
        return factory;
    }
}
