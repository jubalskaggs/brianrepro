package com.brianrepro.pong.model;

import java.time.LocalDateTime;

public class ChatMessage {
    private String content;
    private String sender;
    private String service;
    private LocalDateTime timestamp;

    public ChatMessage() {}

    public ChatMessage(String content, String sender, String service) {
        this.content = content;
        this.sender = sender;
        this.service = service;
        this.timestamp = LocalDateTime.now();
    }

    // Getters and Setters
    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getSender() {
        return sender;
    }

    public void setSender(String sender) {
        this.sender = sender;
    }

    public String getService() {
        return service;
    }

    public void setService(String service) {
        this.service = service;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return "ChatMessage{" +
                "content='" + content + '\'' +
                ", sender='" + sender + '\'' +
                ", service='" + service + '\'' +
                ", timestamp=" + timestamp +
                '}';
    }
}
