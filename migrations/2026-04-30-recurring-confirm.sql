-- ============================================
-- Migration: 2026-04-30
-- Adds website-based 24h confirm flow for recurring slots.
-- Parallel to the existing cancelled_dates field.
-- ============================================

-- 添加 confirmed_dates 数组,与 cancelled_dates 对称:
--   - cancelled_dates: 家长明确不来的日期
--   - confirmed_dates: 家长明确确认的日期
--   - 两者都没的日期 → "待确认"; 应用层用 release.created_at + 24h 判断是否还在占座窗口
alter table recurring_approved
  add column if not exists confirmed_dates date[] default '{}';

-- 没有索引需求(数组成员检查在客户端做,数据量小)
-- 没有 RLS 需求(继承现有的 recurring_approved 策略, "anyone update" 已经允许家长更新)
