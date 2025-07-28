package main

import (
    "fmt"
    "log"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"
    "strings"

    "github.com/gin-contrib/sessions"
    "github.com/gin-contrib/sessions/cookie"
    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
)

type Config struct {
    AuthUsername  string
    AuthPassword  string
    ServerPort    string
    TtydURL       string
    SessionSecret string
    SessionName   string
    SecureCookie  bool
    HTTPOnly      bool
    Environment   string
}

var config Config

func init() {
    // Load .env file
    if err := godotenv.Load(); err != nil {
        log.Println("Warning: .env file not found, using system environment variables")
    }

    // Load configuration from environment
    config = Config{
        AuthUsername:  getEnv("AUTH_USERNAME", "admin"),
        AuthPassword:  getEnv("AUTH_PASSWORD", "admin123"),
        ServerPort:    getEnv("SERVER_PORT", "3000"),
        TtydURL:       getEnv("TTYD_URL", "http://localhost:7681"),
        SessionSecret: getEnv("SESSION_SECRET", "secret-key-change-this"),
        SessionName:   getEnv("SESSION_NAME", "terminal_session"),
        SecureCookie:  getEnvBool("SECURE_COOKIE", false),
        HTTPOnly:      getEnvBool("HTTP_ONLY", true),
        Environment:   getEnv("ENV", "development"),
    }

    // Set Gin mode based on environment
    if config.Environment == "production" {
        gin.SetMode(gin.ReleaseMode)
    }
}

func main() {
    r := gin.Default()

    // Setup sessions
    store := cookie.NewStore([]byte(config.SessionSecret))
    store.Options(sessions.Options{
        Path:     "/",
        HttpOnly: config.HTTPOnly,
        Secure:   config.SecureCookie,
    })
    r.Use(sessions.Sessions(config.SessionName, store))

    // Load HTML templates
    r.LoadHTMLGlob("templates/*")

    // Public routes
    r.GET("/login", loginPage)
    r.POST("/login", handleLogin)
    r.GET("/logout", handleLogout)

    // Protected routes
    authorized := r.Group("/")
    authorized.Use(authRequired())
    {
        // Proxy all requests to ttyd
        authorized.Any("/*path", proxyToTtyd())
    }

    // Start server
    addr := fmt.Sprintf(":%s", config.ServerPort)
    log.Printf("Starting web terminal server on %s", addr)
    log.Printf("Environment: %s", config.Environment)
    log.Printf("Ttyd URL: %s", config.TtydURL)
    
    if err := r.Run(addr); err != nil {
        log.Fatalf("Failed to start server: %v", err)
    }
}

func loginPage(c *gin.Context) {
    c.HTML(http.StatusOK, "login.html", gin.H{
        "error": c.Query("error"),
    })
}

func handleLogin(c *gin.Context) {
    username := c.PostForm("username")
    password := c.PostForm("password")

    if username == config.AuthUsername && password == config.AuthPassword {
        session := sessions.Default(c)
        session.Set("authenticated", true)
        session.Set("username", username)
        if err := session.Save(); err != nil {
            log.Printf("Failed to save session: %v", err)
            c.Redirect(http.StatusFound, "/login?error=1")
            return
        }
        c.Redirect(http.StatusFound, "/")
        return
    }

    c.Redirect(http.StatusFound, "/login?error=1")
}

func handleLogout(c *gin.Context) {
    session := sessions.Default(c)
    session.Clear()
    session.Save()
    c.Redirect(http.StatusFound, "/login")
}

func authRequired() gin.HandlerFunc {
    return func(c *gin.Context) {
        session := sessions.Default(c)
        authenticated := session.Get("authenticated")
        if authenticated != true {
            c.Redirect(http.StatusFound, "/login")
            c.Abort()
            return
        }
        c.Next()
    }
}

func proxyToTtyd() gin.HandlerFunc {
    target, err := url.Parse(config.TtydURL)
    if err != nil {
        log.Fatalf("Invalid ttyd URL: %v", err)
    }
    
    proxy := httputil.NewSingleHostReverseProxy(target)
    
    // Custom director to handle WebSocket upgrades
    originalDirector := proxy.Director
    proxy.Director = func(req *http.Request) {
        originalDirector(req)
        // Ensure proper headers for WebSocket
        if strings.ToLower(req.Header.Get("Connection")) == "upgrade" &&
           strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
            req.Header.Set("Host", target.Host)
        }
    }

    return func(c *gin.Context) {
        proxy.ServeHTTP(c.Writer, c.Request)
    }
}

// Helper functions
func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
    value := os.Getenv(key)
    switch strings.ToLower(value) {
    case "true", "1", "yes", "on":
        return true
    case "false", "0", "no", "off":
        return false
    default:
        return defaultValue
    }
}