package com.brianrepro.pong.service;

import com.brianrepro.pong.model.ChatMessage;
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

    @Value("${app.artemis.queue.ping}")
    private String pingQueue;

    @Value("${app.artemis.queue.pong}")
    private String pongQueue;

    @JmsListener(destination = "${app.artemis.queue.ping}")
    public void receiveMessage(ChatMessage message) {
        System.out.println("Pong service received message: " + message);
        
        // Forward the message to WebSocket clients
        messagingTemplate.convertAndSend("/topic/messages", message);
    }

    public void sendMessage(ChatMessage message) {
        System.out.println("Pong service sending message: " + message);
        
        // Send message to pong queue so ping service can receive it
        jmsTemplate.convertAndSend(pongQueue, message);
    }
}
