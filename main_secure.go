package main

import (
    "fmt"
    "log"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"
    "strings"
    "sync"
    "time"

    "github.com/gin-contrib/sessions"
    "github.com/gin-contrib/sessions/cookie"
    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
)

type Config struct {
    AuthUsername     string
    AuthPassword     string
    ServerPort       string
    TtydURL          string
    SessionSecret    string
    SessionName      string
    SecureCookie     bool
    HTTPOnly         bool
    Environment      string
    MaxLoginAttempts int
    SessionTimeout   int // 分钟
    AllowedIPs       string
}

var (
    config       Config
    loginAttempts = make(map[string]*LoginAttempt)
    loginMutex    sync.RWMutex
    startTime     = time.Now()
)

type LoginAttempt struct {
    Count      int
    LastAttempt time.Time
    LockedUntil time.Time
}

func init() {
    // Load .env file
    if err := godotenv.Load(); err != nil {
        log.Println("Warning: .env file not found, using system environment variables")
    }

    // Load configuration from environment
    config = Config{
        AuthUsername:     getEnv("AUTH_USERNAME", "admin"),
        AuthPassword:     getEnv("AUTH_PASSWORD", "admin123"),
        ServerPort:       getEnv("SERVER_PORT", "3000"),
        TtydURL:          getEnv("TTYD_URL", "http://localhost:7681"),
        SessionSecret:    getEnv("SESSION_SECRET", "secret-key-change-this"),
        SessionName:      getEnv("SESSION_NAME", "terminal_session"),
        SecureCookie:     getEnvBool("SECURE_COOKIE", false),
        HTTPOnly:         getEnvBool("HTTP_ONLY", true),
        Environment:      getEnv("ENV", "development"),
        MaxLoginAttempts: getEnvInt("MAX_LOGIN_ATTEMPTS", 5),
        SessionTimeout:   getEnvInt("SESSION_TIMEOUT", 30),
        AllowedIPs:       getEnv("ALLOWED_IPS", ""), // 空表示允许所有
    }

    // 验证必要的安全配置
    if config.SessionSecret == "secret-key-change-this" || len(config.SessionSecret) < 32 {
        log.Fatal("ERROR: SESSION_SECRET must be changed and at least 32 characters long")
    }

    if config.AuthPassword == "admin123" || len(config.AuthPassword) < 8 {
        log.Fatal("ERROR: AUTH_PASSWORD must be changed and at least 8 characters long")
    }

    // Set Gin mode based on environment
    if config.Environment == "production" {
        gin.SetMode(gin.ReleaseMode)
    }
}

func main() {
    r := gin.Default()

    // 添加安全中间件
    r.Use(securityHeaders())
    r.Use(ipWhitelist())

    // Setup sessions with timeout
    store := cookie.NewStore([]byte(config.SessionSecret))
    store.Options(sessions.Options{
        Path:     "/",
        HttpOnly: config.HTTPOnly,
        Secure:   config.SecureCookie,
        MaxAge:   config.SessionTimeout * 60, // 转换为秒
    })
    r.Use(sessions.Sessions(config.SessionName, store))

    // Load HTML templates
    r.LoadHTMLGlob("templates/*")

    // 健康检查端点
    r.GET("/health", healthCheck)

    // Public routes
    r.GET("/login", loginPage)
    r.POST("/login", handleLogin)
    r.GET("/logout", handleLogout)

    // Root redirect
    r.GET("/", func(c *gin.Context) {
        session := sessions.Default(c)
        if session.Get("authenticated") == true {
            c.Redirect(http.StatusFound, "/terminal/")
        } else {
            c.Redirect(http.StatusFound, "/login")
        }
    })

    // Protected routes
    authorized := r.Group("/terminal")
    authorized.Use(authRequired())
    authorized.Use(sessionTimeout())
    {
        authorized.Any("/*path", proxyToTtyd())
    }

    // 启动清理协程
    go cleanupLoginAttempts()

    // Start server
    addr := fmt.Sprintf(":%s", config.ServerPort)
    log.Printf("Starting secure web terminal server on %s", addr)
    log.Printf("Environment: %s", config.Environment)
    log.Printf("Session timeout: %d minutes", config.SessionTimeout)
    log.Printf("Max login attempts: %d", config.MaxLoginAttempts)
    
    if err := r.Run(addr); err != nil {
        log.Fatalf("Failed to start server: %v", err)
    }
}

// 安全头中间件
func securityHeaders() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("X-Content-Type-Options", "nosniff")
        c.Header("X-Frame-Options", "SAMEORIGIN")
        c.Header("X-XSS-Protection", "1; mode=block")
        c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
        
        if config.Environment == "production" {
            c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        }
        c.Next()
    }
}

// IP 白名单中间件
func ipWhitelist() gin.HandlerFunc {
    return func(c *gin.Context) {
        if config.AllowedIPs == "" {
            c.Next()
            return
        }

        clientIP := c.ClientIP()
        allowed := false
        
        for _, ip := range strings.Split(config.AllowedIPs, ",") {
            if strings.TrimSpace(ip) == clientIP || strings.HasPrefix(clientIP, strings.TrimSpace(ip)) {
                allowed = true
                break
            }
        }

        if !allowed {
            log.Printf("Blocked access from IP: %s", clientIP)
            c.AbortWithStatus(http.StatusForbidden)
            return
        }

        c.Next()
    }
}

// 会话超时检查
func sessionTimeout() gin.HandlerFunc {
    return func(c *gin.Context) {
        session := sessions.Default(c)
        
        lastActivity := session.Get("last_activity")
        if lastActivity != nil {
            last, ok := lastActivity.(int64)
            if ok && time.Now().Unix()-last > int64(config.SessionTimeout*60) {
                log.Printf("Session timeout for user: %s", session.Get("username"))
                session.Clear()
                session.Save()
                c.Redirect(http.StatusFound, "/login")
                c.Abort()
                return
            }
        }
        
        session.Set("last_activity", time.Now().Unix())
        session.Save()
        c.Next()
    }
}

// 健康检查
func healthCheck(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "status": "healthy",
        "uptime": time.Since(startTime).Seconds(),
        "version": "1.0.0",
    })
}

func loginPage(c *gin.Context) {
    c.HTML(http.StatusOK, "login.html", gin.H{
        "error": c.Query("error"),
    })
}

func handleLogin(c *gin.Context) {
    username := c.PostForm("username")
    password := c.PostForm("password")
    clientIP := c.ClientIP()

    // 检查登录尝试限制
    if !checkLoginAttempt(clientIP) {
        log.Printf("Too many login attempts from IP: %s", clientIP)
        c.Redirect(http.StatusFound, "/login?error=2") // error=2 表示太多尝试
        return
    }

    if username == config.AuthUsername && password == config.AuthPassword {
        // 重置登录尝试
        resetLoginAttempt(clientIP)
        
        session := sessions.Default(c)
        session.Set("authenticated", true)
        session.Set("username", username)
        session.Set("login_time", time.Now().Unix())
        session.Set("last_activity", time.Now().Unix())
        session.Set("client_ip", clientIP)
        
        if err := session.Save(); err != nil {
            log.Printf("Failed to save session: %v", err)
            c.Redirect(http.StatusFound, "/login?error=1")
            return
        }
        
        log.Printf("Successful login: user=%s ip=%s", username, clientIP)
        c.Redirect(http.StatusFound, "/terminal/")
        return
    }

    // 记录失败的登录尝试
    recordFailedAttempt(clientIP)
    log.Printf("Failed login attempt: user=%s ip=%s", username, clientIP)
    c.Redirect(http.StatusFound, "/login?error=1")
}

func handleLogout(c *gin.Context) {
    session := sessions.Default(c)
    username := session.Get("username")
    clientIP := c.ClientIP()
    
    session.Clear()
    session.Save()
    
    log.Printf("User logout: user=%s ip=%s", username, clientIP)
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

// 登录尝试限制函数
func checkLoginAttempt(ip string) bool {
    loginMutex.RLock()
    attempt, exists := loginAttempts[ip]
    loginMutex.RUnlock()

    if !exists {
        return true
    }

    if time.Now().Before(attempt.LockedUntil) {
        return false
    }

    return attempt.Count < config.MaxLoginAttempts
}

func recordFailedAttempt(ip string) {
    loginMutex.Lock()
    defer loginMutex.Unlock()

    attempt, exists := loginAttempts[ip]
    if !exists {
        attempt = &LoginAttempt{
            Count:       0,
            LastAttempt: time.Now(),
        }
        loginAttempts[ip] = attempt
    }

    attempt.Count++
    attempt.LastAttempt = time.Now()

    if attempt.Count >= config.MaxLoginAttempts {
        // 锁定15分钟
        attempt.LockedUntil = time.Now().Add(15 * time.Minute)
        log.Printf("IP %s locked due to too many failed attempts", ip)
    }
}

func resetLoginAttempt(ip string) {
    loginMutex.Lock()
    defer loginMutex.Unlock()
    delete(loginAttempts, ip)
}

// 定期清理旧的登录尝试记录
func cleanupLoginAttempts() {
    ticker := time.NewTicker(30 * time.Minute)
    defer ticker.Stop()

    for range ticker.C {
        loginMutex.Lock()
        now := time.Now()
        for ip, attempt := range loginAttempts {
            // 清理超过1小时的记录
            if now.Sub(attempt.LastAttempt) > time.Hour {
                delete(loginAttempts, ip)
            }
        }
        loginMutex.Unlock()
    }
}

func proxyToTtyd() gin.HandlerFunc {
    target, err := url.Parse(config.TtydURL)
    if err != nil {
        log.Fatalf("Invalid ttyd URL: %v", err)
    }
    
    proxy := httputil.NewSingleHostReverseProxy(target)
    
    originalDirector := proxy.Director
    proxy.Director = func(req *http.Request) {
        originalDirector(req)
        
        req.URL.Path = strings.TrimPrefix(req.URL.Path, "/terminal")
        if req.URL.Path == "" {
            req.URL.Path = "/"
        }
        
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

func getEnvInt(key string, defaultValue int) int {
    value := os.Getenv(key)
    if value == "" {
        return defaultValue
    }
    
    var result int
    if _, err := fmt.Sscanf(value, "%d", &result); err != nil {
        return defaultValue
    }
    return result
}