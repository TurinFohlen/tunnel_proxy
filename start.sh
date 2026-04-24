#!/bin/bash

# ============================================
# TunnelProxy 启动脚本
# ============================================

# 预设 Agent（支持多个，编号从1开始）
export TUNNEL_PRESET_AGENT_1="agent1:host1:user1:linux"
export TUNNEL_PRESET_AGENT_2="${TUNNEL_PRESET_AGENT_2:-}"
export TUNNEL_PRESET_AGENT_3="${TUNNEL_PRESET_AGENT_3:-}"

# 注册锁（1 = 锁定，禁止新注册）
export TUNNEL_LOCK_REGISTRATION="${TUNNEL_LOCK_REGISTRATION:-1}"

# PTY Gateway 端口（默认 27417）
export TUNNEL_PTY_PORT="${TUNNEL_PTY_PORT:-27417}"

# HTTP 端口（默认 8080）
export TUNNEL_HTTP_PORT="${TUNNEL_HTTP_PORT:-8080}"

# 文档根目录（文件服务器）
export TUNNEL_DOC_ROOT="${TUNNEL_DOC_ROOT:-./www}"

# 上传目录
export TUNNEL_UPLOAD_DIR="${TUNNEL_UPLOAD_DIR:-./uploads}"

# ============================================
# 启动服务
# ============================================
echo "========================================"
echo " TunnelProxy 启动中..."
echo "========================================"
echo " HTTP 端口:      $TUNNEL_HTTP_PORT"
echo " PTY 网关端口:   $TUNNEL_PTY_PORT"
echo " 注册锁:         $TUNNEL_LOCK_REGISTRATION"
echo " 预设 Agent:     $TUNNEL_PRESET_AGENT_1"
echo "========================================"

iex -S mix
