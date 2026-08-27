package printer

import (
	"encoding/base64"
	"fmt"

	"github.com/dynops/bcwms-print-agent/config"
)

type Backend interface {
	Print(format string, payload []byte, copies int) error
}

func New(cfg *config.Config) Backend {
	return newBackend(cfg)
}

func DecodePayload(payloadBase64 string) ([]byte, error) {
	if payloadBase64 == "" {
		return nil, fmt.Errorf("empty payload")
	}
	return base64.StdEncoding.DecodeString(payloadBase64)
}
