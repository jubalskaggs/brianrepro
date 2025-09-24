package com.brianrepro.pong.controller;

import com.brianrepro.pong.model.ChatMessage;
import com.brianrepro.pong.service.ChatService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class ChatController {

    @Autowired
    private ChatService chatService;

    @Value("${app.service.name}")
    private String serviceName;

    @GetMapping("/")
    public String chatPage(Model model) {
        model.addAttribute("serviceName", serviceName);
        return "chat";
    }

    @GetMapping("/pong")
    public String pongPage(Model model) {
        model.addAttribute("serviceName", serviceName);
        return "chat";
    }

    @MessageMapping("/chat.sendMessage")
    @SendTo("/topic/messages")
    public ChatMessage sendMessage(ChatMessage message) {
        message.setService(serviceName);
        chatService.sendMessage(message);
        return message;
    }
}
