package service

import (
	"context"
	"testing"
	"time"

	"github.com/Wei-Shaw/sub2api/internal/config"
	"github.com/stretchr/testify/require"
)

func TestIsReservedEmail_DingTalkDomain(t *testing.T) {
	require.True(t, isReservedEmail("dingtalk-123@dingtalk-connect.invalid"))
	require.True(t, isReservedEmail("DINGTALK-456@DINGTALK-CONNECT.INVALID")) // case-insensitive
	require.False(t, isReservedEmail("real@dingtalk.com"))
}

type captureRefreshTokenCache struct {
	data *RefreshTokenData
	ttl  time.Duration
}

func (c *captureRefreshTokenCache) StoreRefreshToken(_ context.Context, _ string, data *RefreshTokenData, ttl time.Duration) error {
	c.data = data
	c.ttl = ttl
	return nil
}

func (c *captureRefreshTokenCache) GetRefreshToken(context.Context, string) (*RefreshTokenData, error) {
	return nil, ErrRefreshTokenNotFound
}

func (c *captureRefreshTokenCache) DeleteRefreshToken(context.Context, string) error {
	return nil
}

func (c *captureRefreshTokenCache) DeleteUserRefreshTokens(context.Context, int64) error {
	return nil
}

func (c *captureRefreshTokenCache) DeleteTokenFamily(context.Context, string) error {
	return nil
}

func (c *captureRefreshTokenCache) AddToUserTokenSet(context.Context, int64, string, time.Duration) error {
	return nil
}

func (c *captureRefreshTokenCache) AddToFamilyTokenSet(context.Context, string, string, time.Duration) error {
	return nil
}

func (c *captureRefreshTokenCache) GetUserTokenHashes(context.Context, int64) ([]string, error) {
	return nil, nil
}

func (c *captureRefreshTokenCache) GetFamilyTokenHashes(context.Context, string) ([]string, error) {
	return nil, nil
}

func (c *captureRefreshTokenCache) IsTokenInFamily(context.Context, string, string) (bool, error) {
	return false, nil
}

func TestGenerateTokenPairWithRememberMeUsesConfiguredRefreshTTL(t *testing.T) {
	user := &User{ID: 1, Email: "test@example.com", Role: RoleUser, Status: StatusActive}

	tests := []struct {
		name       string
		rememberMe bool
		wantTTL    time.Duration
	}{
		{name: "short session", rememberMe: false, wantTTL: 12 * time.Hour},
		{name: "remembered session", rememberMe: true, wantTTL: 30 * 24 * time.Hour},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cache := &captureRefreshTokenCache{}
			authService := &AuthService{
				refreshTokenCache: cache,
				cfg: &config.Config{JWT: config.JWTConfig{
					Secret:                         "test-secret",
					ExpireHour:                     24,
					RefreshTokenExpireDays:         30,
					SessionRefreshTokenExpireHours: 12,
				}},
			}

			pair, err := authService.GenerateTokenPairWithRememberMe(context.Background(), user, "", tt.rememberMe)

			require.NoError(t, err)
			require.NotEmpty(t, pair.AccessToken)
			require.NotEmpty(t, pair.RefreshToken)
			require.Equal(t, tt.wantTTL, cache.ttl)
			require.NotNil(t, cache.data)
			require.NotNil(t, cache.data.RememberMe)
			require.Equal(t, tt.rememberMe, *cache.data.RememberMe)
		})
	}
}
