package relay

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/dynops/bcwms-print-agent/config"
)

type Client struct {
	cfg  *config.Config
	http *http.Client
}

type Job struct {
	JobID       int    `json:"jobId"`
	SourceDoc   string `json:"sourceDoc"`
	PrinterID   string `json:"printerId"`
	Channel     string `json:"channel"`
	Format      string `json:"format"`
	Status      string `json:"status"`
	Copies      int    `json:"copies"`
	Payload     string `json:"payload"`
	PayloadSize int    `json:"payloadSize"`
	CreatedAt   string `json:"createdAt"`
}

type listResponse struct {
	OK   bool  `json:"ok"`
	Jobs []Job `json:"jobs"`
}

func NewClient(cfg *config.Config) *Client {
	return &Client{
		cfg: cfg,
		http: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *Client) ListJobs(ctx context.Context) ([]Job, error) {
	q := url.Values{}
	q.Set("printer", c.cfg.PrinterID)
	q.Set("tenant", c.cfg.TenantID)
	q.Set("agent", c.cfg.AgentID)
	q.Set("top", "10")
	endpoint := fmt.Sprintf("%s/api/print-jobs?%s", c.cfg.RelayURL, q.Encode())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	c.sign(req, []byte(""))
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("list jobs status=%d body=%s", resp.StatusCode, string(body))
	}
	var parsed listResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	return parsed.Jobs, nil
}

func (c *Client) Claim(ctx context.Context, jobID int) error {
	body, _ := json.Marshal(map[string]string{"agentId": c.cfg.AgentID})
	return c.post(ctx, fmt.Sprintf("/api/print-jobs/%d/claim", jobID), body)
}

func (c *Client) MarkSuccess(ctx context.Context, jobID int, message string) error {
	body, _ := json.Marshal(map[string]string{"status": "Sent", "message": message, "agentId": c.cfg.AgentID})
	return c.post(ctx, fmt.Sprintf("/api/print-jobs/%d/status", jobID), body)
}

func (c *Client) MarkFailure(ctx context.Context, jobID int, message string) error {
	body, _ := json.Marshal(map[string]string{"status": "Failed", "message": message, "agentId": c.cfg.AgentID})
	return c.post(ctx, fmt.Sprintf("/api/print-jobs/%d/status", jobID), body)
}

func (c *Client) post(ctx context.Context, path string, body []byte) error {
	q := url.Values{}
	q.Set("printer", c.cfg.PrinterID)
	q.Set("tenant", c.cfg.TenantID)
	endpoint := fmt.Sprintf("%s%s?%s", c.cfg.RelayURL, path, q.Encode())
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	c.sign(req, body)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		buf, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("post %s status=%d body=%s", path, resp.StatusCode, string(buf))
	}
	return nil
}

func (c *Client) sign(req *http.Request, body []byte) {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	// Per-request nonce: relay retains it until the signed timestamp leaves
	// the accepted window and rejects reuse. Combined with the timestamp
	// check, this blocks replay on a running relay instance.
	nonceBytes := make([]byte, 16)
	_, _ = rand.Read(nonceBytes)
	nonce := hex.EncodeToString(nonceBytes)

	mac := hmac.New(sha256.New, []byte(c.cfg.Secret))
	canonical := req.Method + "\n" + req.URL.EscapedPath() + "\n" + req.URL.RawQuery + "\n" + string(body)
	mac.Write([]byte(ts))
	mac.Write([]byte("."))
	mac.Write([]byte(nonce))
	mac.Write([]byte("."))
	mac.Write([]byte(canonical))
	sig := hex.EncodeToString(mac.Sum(nil))
	req.Header.Set("X-Bcwms-Printer-Id", c.cfg.PrinterID)
	req.Header.Set("X-Bcwms-Timestamp", ts)
	req.Header.Set("X-Bcwms-Nonce", nonce)
	req.Header.Set("X-Bcwms-Signature", sig)
}
