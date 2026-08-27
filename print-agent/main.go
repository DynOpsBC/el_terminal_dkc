package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/dynops/bcwms-print-agent/agent"
	"github.com/dynops/bcwms-print-agent/config"
	"github.com/dynops/bcwms-print-agent/printer"
	"github.com/dynops/bcwms-print-agent/relay"
)

func main() {
	configPath := flag.String("config", defaultConfigPath(), "path to config.json")
	flag.Parse()

	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	logger := log.New(os.Stdout, "[bcwms-print-agent] ", log.LstdFlags|log.Lshortfile)
	logger.Printf("starting agent printer=%s relay=%s interval=%ds", cfg.PrinterID, cfg.RelayURL, cfg.PollIntervalSec)

	client := relay.NewClient(cfg)
	printerBackend := printer.New(cfg)

	a := &agent.Agent{
		Cfg:     cfg,
		Client:  client,
		Printer: printerBackend,
		Logger:  logger,
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	if err := a.Run(ctx, time.Duration(cfg.PollIntervalSec)*time.Second); err != nil && ctx.Err() == nil {
		logger.Fatalf("agent terminated: %v", err)
	}
	logger.Println("agent stopped cleanly")
}

func defaultConfigPath() string {
	if v := os.Getenv("BCWMS_AGENT_CONFIG"); v != "" {
		return v
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "config.json"
	}
	return home + string(os.PathSeparator) + ".bcwms-print-agent" + string(os.PathSeparator) + "config.json"
}
