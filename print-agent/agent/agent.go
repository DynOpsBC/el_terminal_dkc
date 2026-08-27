package agent

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/dynops/bcwms-print-agent/config"
	"github.com/dynops/bcwms-print-agent/printer"
	"github.com/dynops/bcwms-print-agent/relay"
)

type Agent struct {
	Cfg     *config.Config
	Client  *relay.Client
	Printer printer.Backend
	Logger  *log.Logger
}

func (a *Agent) Run(ctx context.Context, interval time.Duration) error {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	a.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			a.tick(ctx)
		}
	}
}

func (a *Agent) tick(ctx context.Context) {
	jobs, err := a.Client.ListJobs(ctx)
	if err != nil {
		if errors.Is(err, context.Canceled) {
			return
		}
		a.Logger.Printf("list error: %v", err)
		return
	}
	for _, job := range jobs {
		if err := a.process(ctx, job); err != nil {
			a.Logger.Printf("job %d failed: %v", job.JobID, err)
		}
	}
}

func (a *Agent) process(ctx context.Context, job relay.Job) error {
	if err := a.Client.Claim(ctx, job.JobID); err != nil {
		return err
	}
	payload, err := printer.DecodePayload(job.Payload)
	if err != nil {
		_ = a.Client.MarkFailure(ctx, job.JobID, "decode: "+err.Error())
		return err
	}
	if job.PayloadSize > 0 && len(payload) != job.PayloadSize {
		err = fmt.Errorf("payload size mismatch: decoded=%d expected=%d", len(payload), job.PayloadSize)
		_ = a.Client.MarkFailure(ctx, job.JobID, err.Error())
		return err
	}
	copies := job.Copies
	if copies <= 0 {
		copies = 1
	}
	if copies > 10 {
		err = fmt.Errorf("copies %d exceeds the agent limit of 10", copies)
		_ = a.Client.MarkFailure(ctx, job.JobID, err.Error())
		return err
	}
	if err := a.Printer.Print(job.Format, payload, copies); err != nil {
		_ = a.Client.MarkFailure(ctx, job.JobID, err.Error())
		return err
	}
	if err := a.Client.MarkSuccess(ctx, job.JobID, "ok"); err != nil {
		return err
	}
	a.Logger.Printf("job %d printed (%d bytes, %d copies)", job.JobID, len(payload), copies)
	return nil
}
