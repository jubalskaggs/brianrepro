package com.brianrepro.ping.service;

import com.brianrepro.ping.model.ChatMessage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Service
public class ChatService {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private JmsTemplate jmsTemplate;

    @Value("${app.artemis.queue.pong}")
    private String pongQueue;

    @Value("${app.artemis.queue.ping}")
    private String pingQueue;

    @JmsListener(destination = "${app.artemis.queue.pong}")
    public void receiveMessage(ChatMessage message) {
        System.out.println("Ping service received message: " + message);
        
        // Forward the message to WebSocket clients
        messagingTemplate.convertAndSend("/topic/messages", message);
    }

    public void sendMessage(ChatMessage message) {
        System.out.println("Ping service sending message: " + message);
        
        // Send message to ping queue so pong service can receive it
        jmsTemplate.convertAndSend(pingQueue, message);
    }
}
