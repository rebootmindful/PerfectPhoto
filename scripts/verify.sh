#!/usr/bin/env bash
# PerfectPhoto Skill 验证脚本
# 用法: bash scripts/verify.sh
# 输出: PASS/WARN/FAIL + 每项检查状态

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
WARN=0
FAIL=0
TOTAL=0

check() {
    TOTAL=$((TOTAL + 1))
    local name="$1" status="$2"
    local detail="${3:-}"
    case "$status" in
        PASS) PASS=$((PASS + 1)); echo "  ✅ PASS  $name" ;;
        WARN) WARN=$((WARN + 1)); echo "  ⚠️  WARN  $name${detail:+ — $detail}" ;;
        FAIL) FAIL=$((FAIL + 1)); echo "  ❌ FAIL  $name${detail:+ — $detail}" ;;
    esac
}

echo "════════════════════════════════════════"
echo "  PerfectPhoto Skill 验证"
echo "════════════════════════════════════════"
echo ""

# ─── 1. Frontmatter ──────────────────────────────────────────────
echo "── 1. Frontmatter ──"

SKILL_FM=$(sed -n '1,/^---$/p' SKILL.md 2>/dev/null || echo "")
if echo "$SKILL_FM" | grep -q "^name: PerfectPhoto"; then
    check "name: PerfectPhoto" PASS
else
    check "name: PerfectPhoto" FAIL "name 字段缺失或不匹配"
fi

if echo "$SKILL_FM" | grep -q "^platforms:"; then
    check "platforms 字段存在" PASS
else
    check "platforms 字段存在" WARN "缺 platforms 声明"
fi

echo ""

# ─── 2. 文件完整性 ───────────────────────────────────────────────
echo "── 2. 文件完整性 ──"

for f in SKILL.md reference.md community-examples.md README.md NextShotPhoto-SPEC.md; do
    if [ -f "$f" ]; then
        check "$f 存在" PASS
    else
        check "$f 存在" FAIL "文件缺失"
    fi
done

for f in nextshotphoto-references/transform-matrix.md \
         nextshotphoto-references/master-cinematography.md \
         nextshotphoto-references/negative-constraints.md; do
    if [ -f "$f" ]; then
        check "$f 存在" PASS
    else
        check "$f 存在" FAIL "文件缺失"
    fi
done

echo ""

# ─── 3. SKILL.md 行数检查 ────────────────────────────────────────
echo "── 3. SKILL.md 行数 ──"

LINES=$(wc -l < SKILL.md)
if [ "$LINES" -le 800 ]; then
    check "SKILL.md ≤ 800 行 (当前 ${LINES})" PASS
elif [ "$LINES" -le 1500 ]; then
    check "SKILL.md ≤ 1500 行 (当前 ${LINES})" WARN "超出品味基线 800 行，建议拆分"
else
    check "SKILL.md (当前 ${LINES})" FAIL "超过 1500 行，严重影响可维护性"
fi

echo ""

# ─── 4. test-prompts.json ────────────────────────────────────────
echo "── 4. test-prompts.json ──"

if [ -f test-prompts.json ]; then
    if python3 -c "import json; json.load(open('test-prompts.json', encoding='utf-8'))" 2>/dev/null || python -c "import json; json.load(open('test-prompts.json', encoding='utf-8'))" 2>/dev/null; then
        COUNT=$(python3 -c "import json; print(len(json.load(open('test-prompts.json', encoding='utf-8'))))" 2>/dev/null || python -c "import json; print(len(json.load(open('test-prompts.json', encoding='utf-8'))))" 2>/dev/null || echo "0")
        check "test-prompts.json 有效 JSON (${COUNT} 个用例)" PASS
    else
        check "test-prompts.json 有效 JSON" FAIL "解析失败"
    fi
else
    check "test-prompts.json 存在" FAIL "缺失，无法验证"
fi

echo ""

# ─── 5. Showcase 图片 ────────────────────────────────────────────
echo "── 5. Showcase 图片 ──"

SHOWCASE_COUNT=$(ls -1 showcase/*.png 2>/dev/null | wc -l)
if [ "$SHOWCASE_COUNT" -ge 5 ]; then
    check "showcase/ 有 ${SHOWCASE_COUNT} 张 PNG" PASS
else
    check "showcase/ PNG 数量 (${SHOWCASE_COUNT})" WARN "建议至少 5 张展示图"
fi

# 检查水印
HAS_WATERMARK=0
for img in showcase/*.png; do
    if echo "$img" | grep -qE "(dragoncode|daisy-field|flash|studio|mist)"; then
        continue  # 跳过 E2E 产物的二进制校验
    fi
done
# 改用文件尺寸做合理性检查（>500KB 一般是真图）
SMALL=0
for img in showcase/*.png; do
    SIZE=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img" 2>/dev/null)
    if [ "${SIZE:-0}" -lt 500000 ]; then
        SMALL=$((SMALL + 1))
    fi
done
if [ "$SMALL" -eq 0 ]; then
    check "showcase 图片均 > 500KB" PASS
else
    check "${SMALL} 张图片 < 500KB" WARN "可能不是原始出图分辨率"
fi

echo ""

# ─── 6. 安全边界检查 ────────────────────────────────────────────
echo "── 6. 安全边界 ──"

if grep -q "NSFW" SKILL.md; then
    check "安全边界包含 NSFW 拦截" PASS
else
    check "安全边界包含 NSFW 拦截" FAIL "缺少 NSFW 安全声明"
fi

if grep -q "负面约束\|不要塑料皮肤" SKILL.md; then
    check "负面约束默认项存在" PASS
else
    check "负面约束默认项存在" FAIL "缺少负面约束"
fi

echo ""

# ─── 7. README 首屏检查 ─────────────────────────────────────────
echo "── 7. README 首屏 ──"

if grep -q "^# PerfectPhoto" README.md; then
    check "README 标题正确" PASS
else
    check "README 标题正确" FAIL
fi

if grep -q "skills.sh" README.md; then
    check "skills.sh 徽章存在" PASS
else
    check "skills.sh 徽章存在" WARN "无 skills.sh 徽章"
fi

if grep -q "快速验证" README.md; then
    check "README 有快速验证章节" PASS
else
    check "README 有快速验证章节" WARN "缺少快速验证引导"
fi

echo ""

# ─── 8. NextShotPhoto 状态同步 ──────────────────────────────────
echo "── 8. NextShotPhoto SPEC 状态 ──"

if grep -q "已实现" NextShotPhoto-SPEC.md; then
    check "SPEC 状态标记为「已实现」" PASS
else
    check "SPEC 状态标记" FAIL "SPEC 仍标注待实现"
fi

echo ""

# ─── 汇总 ────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
echo "  结果: PASS ${PASS}  WARN ${WARN}  FAIL ${FAIL}  共 ${TOTAL} 项"
echo "════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo "❌ 存在 FAIL 项，建议修复后再发布。"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "⚠️  存在 WARN 项，建议检查但不阻塞。"
    exit 0
else
    echo "✅ 全部通过。"
    exit 0
fi
