package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/pi-sandbox/go-client/pkg/client"
	"github.com/pi-sandbox/go-client/pkg/security"
)

// Server 是 HTTP API 服务器
type Server struct {
	manager *client.AgentManager
	policy  *security.SecurityPolicy
	audit   *security.AuditLogger
	port    string
}

// NewServer 创建新的服务器
func NewServer(workDir, port string) *Server {
	policy := security.DefaultSecurityPolicy()
	
	audit := security.NewAuditLogger(true, func(level, message string, fields map[string]interface{}) {
		log.Printf("[%s] %s: %v", level, message, fields)
	})
	
	config := client.DefaultManagerConfig()
	manager := client.NewAgentManager(workDir, config)
	
	return &Server{
		manager: manager,
		policy:  policy,
		audit:   audit,
		port:    port,
	}
}

// Start 启动服务器
func (s *Server) Start() error {
	mux := http.NewServeMux()
	
	// API 路由
	mux.HandleFunc("/api/sessions", s.handleSessions)
	mux.HandleFunc("/api/sessions/", s.handleSession)
	mux.HandleFunc("/api/prompt", s.handlePrompt)
	mux.HandleFunc("/api/status", s.handleStatus)
	mux.HandleFunc("/api/health", s.handleHealth)
	
	server := &http.Server{
		Addr:    s.port,
		Handler: mux,
	}
	
	// 优雅关闭
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan
		
		log.Println("Shutting down server...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		
		s.manager.CloseAll()
		server.Shutdown(ctx)
	}()
	
	log.Printf("Server starting on %s", s.port)
	return server.ListenAndServe()
}

// handleSessions 处理会话列表请求
func (s *Server) handleSessions(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		sessions := s.manager.ListSessions()
		s.writeJSON(w, http.StatusOK, map[string]interface{}{
			"sessions": sessions,
			"count":    len(sessions),
		})
		
	case http.MethodPost:
		var req struct {
			ID   string   `json:"id"`
			Args []string `json:"args"`
		}
		
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			s.writeError(w, http.StatusBadRequest, "Invalid request body")
			return
		}
		
		if req.ID == "" {
			req.ID = fmt.Sprintf("session-%d", time.Now().Unix())
		}
		
		session, err := s.manager.CreateSession(req.ID, req.Args...)
		if err != nil {
			s.writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		
		s.writeJSON(w, http.StatusCreated, map[string]interface{}{
			"id":         session.ID,
			"created_at": session.CreatedAt,
		})
		
	default:
		s.writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
	}
}

// handleSession 处理单个会话请求
func (s *Server) handleSession(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Path[len("/api/sessions/"):]
	
	switch r.Method {
	case http.MethodGet:
		session, err := s.manager.GetSession(sessionID)
		if err != nil {
			s.writeError(w, http.StatusNotFound, err.Error())
			return
		}
		
		s.writeJSON(w, http.StatusOK, map[string]interface{}{
			"id":         session.ID,
			"created_at": session.CreatedAt,
			"last_used":  session.LastUsed,
			"metadata":   session.Metadata,
		})
		
	case http.MethodDelete:
		if err := s.manager.CloseSession(sessionID); err != nil {
			s.writeError(w, http.StatusNotFound, err.Error())
			return
		}
		
		s.writeJSON(w, http.StatusOK, map[string]interface{}{
			"message": "Session closed",
		})
		
	default:
		s.writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
	}
}

// handlePrompt 处理提示请求
func (s *Server) handlePrompt(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	
	var req struct {
		SessionID string `json:"session_id"`
		Message   string `json:"message"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	
	if req.SessionID == "" || req.Message == "" {
		s.writeError(w, http.StatusBadRequest, "session_id and message are required")
		return
	}
	
	// 安全检查
	validator := security.NewToolCallValidator(s.policy)
	if err := validator.ValidateToolCall("prompt", map[string]interface{}{"message": req.Message}); err != nil {
		s.audit.LogToolCall("prompt", map[string]interface{}{"message": req.Message}, false, err.Error())
		s.writeError(w, http.StatusForbidden, err.Error())
		return
	}
	
	s.audit.LogPrompt(req.Message)
	
	session, err := s.manager.GetSession(req.SessionID)
	if err != nil {
		s.writeError(w, http.StatusNotFound, err.Error())
		return
	}
	
	if err := session.Client.Prompt(req.Message); err != nil {
		s.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	
	s.writeJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Prompt sent",
	})
}

// handleStatus 处理状态请求
func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	
	sessions := s.manager.ListSessions()
	
	s.writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":        "running",
		"sessions":      len(sessions),
		"max_sessions":  10,
		"uptime":        time.Since(startTime).String(),
	})
}

// handleHealth 处理健康检查请求
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	s.writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "healthy",
	})
}

// writeJSON 写入 JSON 响应
func (s *Server) writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// writeError 写入错误响应
func (s *Server) writeError(w http.ResponseWriter, status int, message string) {
	s.writeJSON(w, status, map[string]interface{}{
		"error": message,
	})
}

var startTime = time.Now()

func main() {
	workDir := os.Getenv("WORK_DIR")
	if workDir == "" {
		workDir = "/workspace"
	}
	
	port := os.Getenv("PORT")
	if port == "" {
		port = ":8080"
	}
	
	server := NewServer(workDir, port)
	
	log.Fatal(server.Start())
}
