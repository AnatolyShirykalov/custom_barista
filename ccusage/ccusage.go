package ccusage

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"time"

	"barista.run/bar"
	"barista.run/colors"
	"barista.run/outputs"
)

type TokenCounts struct {
	InputTokens              int64 `json:"inputTokens"`
	OutputTokens             int64 `json:"outputTokens"`
	CacheCreationInputTokens int64 `json:"cacheCreationInputTokens"`
	CacheReadInputTokens     int64 `json:"cacheReadInputTokens"`
}

type Projection struct {
	TotalTokens      int64   `json:"totalTokens"`
	TotalCost        float64 `json:"totalCost"`
	RemainingMinutes int     `json:"remainingMinutes"`
}

type TokenLimitStatus struct {
	Limit          int64   `json:"limit"`
	ProjectedUsage int64   `json:"projectedUsage"`
	PercentUsed    float64 `json:"percentUsed"`
	Status         string  `json:"status"`
}

type Block struct {
	ID               string            `json:"id"`
	StartTime        string            `json:"startTime"`
	EndTime          string            `json:"endTime"`
	IsActive         bool              `json:"isActive"`
	IsGap            bool              `json:"isGap"`
	TokenCounts      TokenCounts       `json:"tokenCounts"`
	TotalTokens      int64             `json:"totalTokens"`
	CostUSD          float64           `json:"costUSD"`
	Projection       *Projection       `json:"projection"`
	TokenLimitStatus *TokenLimitStatus `json:"tokenLimitStatus"`
}

type BlocksResponse struct {
	Blocks []Block `json:"blocks"`
}

type UsageData struct {
	CurrentTokens    int64
	ProjectedTokens  int64
	RemainingMinutes int
	UsagePercentage  float64
	CacheHitRatio    float64
}

type CCUsageModule struct{}

func formatTokens(tokens int64) string {
	if tokens >= 1000000 {
		return fmt.Sprintf("%.1fM", float64(tokens)/1000000)
	} else if tokens >= 1000 {
		return fmt.Sprintf("%.1fK", float64(tokens)/1000)
	}
	return fmt.Sprintf("%d", tokens)
}

func getUsageData() (*UsageData, error) {
	cmd := exec.Command("npx", "ccusage@latest", "blocks", "--active", "--token-limit", "max", "--json")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var response BlocksResponse
	if err := json.Unmarshal(output, &response); err != nil {
		return nil, err
	}

	usage := &UsageData{}

	// Find the active block
	for _, block := range response.Blocks {
		if block.IsActive && !block.IsGap {
			usage.CurrentTokens = block.TotalTokens
			usage.RemainingMinutes = 0

			if block.Projection != nil {
				usage.ProjectedTokens = block.Projection.TotalTokens
				usage.RemainingMinutes = block.Projection.RemainingMinutes
			}

			// Calculate usage percentage against actual Claude token limit
			if block.TokenLimitStatus != nil && block.TokenLimitStatus.Limit > 0 {
				usage.UsagePercentage = float64(block.TotalTokens) / float64(block.TokenLimitStatus.Limit) * 100
			}

			// Calculate cache hit ratio
			totalCacheTokens := block.TokenCounts.CacheReadInputTokens
			totalInputTokens := block.TokenCounts.InputTokens + block.TokenCounts.CacheCreationInputTokens + block.TokenCounts.CacheReadInputTokens
			if totalInputTokens > 0 {
				usage.CacheHitRatio = float64(totalCacheTokens) / float64(totalInputTokens) * 100
			}
			break
		}
	}

	return usage, nil
}

func (m *CCUsageModule) Stream(sink bar.Sink) {
	// Initial update
	m.updateUsage(sink)

	// Then update every 5 seconds (less frequent to avoid API rate limits)
	for range time.Tick(5 * time.Second) {
		m.updateUsage(sink)
	}
}

func (m *CCUsageModule) updateUsage(sink bar.Sink) {
	usage, err := getUsageData()
	if err != nil {
		sink.Output(outputs.Text("ccusage: error").Color(colors.Scheme("bad")))
		return
	}

	// If no active session, show a simple message
	if usage.CurrentTokens == 0 && usage.ProjectedTokens == 0 {
		sink.Output(outputs.Pango(
			"",
		).Color(colors.Scheme("dim-icon")))
		return
	}

	// Format time remaining
	timeStr := ""
	if usage.RemainingMinutes > 0 {
		hours := usage.RemainingMinutes / 60
		minutes := usage.RemainingMinutes % 60
		if hours > 0 {
			timeStr = fmt.Sprintf(" %dh%dm", hours, minutes)
		} else {
			timeStr = fmt.Sprintf(" %dm", minutes)
		}
	}

	// Build the display string
	displayText := ""
	if usage.UsagePercentage > 0 {
		if usage.UsagePercentage < 1 {
			displayText += fmt.Sprintf("%.1f%%", usage.UsagePercentage)
		} else {
			displayText += fmt.Sprintf("%.0f%%", usage.UsagePercentage)
		}
	}

	// Add human-readable token count
	if usage.CurrentTokens > 0 {
		displayText += fmt.Sprintf(" %s", formatTokens(usage.CurrentTokens))
	}

	// Add cache hit ratio
	if usage.CacheHitRatio > 0 {
		displayText += fmt.Sprintf(" CH %.0f%%", usage.CacheHitRatio)
	}

	displayText += timeStr

	out := outputs.Pango(
		displayText,
	)

	// Color based on usage percentage
	switch {
	case usage.UsagePercentage > 90:
		out.Color(colors.Scheme("bad"))
	case usage.UsagePercentage > 70:
		out.Color(colors.Scheme("degraded"))
	default:
		out.Color(colors.Scheme("good"))
	}

	sink.Output(out)
}

func Get() bar.Module {
	return &CCUsageModule{}
}
