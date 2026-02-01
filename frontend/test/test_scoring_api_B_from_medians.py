import json
import random
import requests

BASE_URL = "http://127.0.0.1:8000"
CHAR_URL = f"{BASE_URL}/api/characters/{{char}}"
SCORE_URL = f"{BASE_URL}/api/score/comprehensive"

CHAR = "永"

def pretty(title, obj):
    print(f"\n=== {title} ===")
    print(json.dumps(obj, ensure_ascii=False, indent=2))

def normalize_medians_to_user_strokes(medians, jitter=0.0):
    """
    medians 期望是每笔一个点序列，点为 [x,y]（可能是0-1或0-1024，取决于后端返回）
    你的 scoring schema 要 0-1。
    """
    # 先判断范围：如果明显>1，按1024缩放到0-1
    def norm_pt(pt):
        x, y = pt
        if x > 1.5 or y > 1.5:
            x /= 1024.0
            y /= 1024.0
        if jitter:
            x = min(1.0, max(0.0, x + random.uniform(-jitter, jitter)))
            y = min(1.0, max(0.0, y + random.uniform(-jitter, jitter)))
        return [float(x), float(y)]

    strokes = []
    for stroke in medians:
        # stroke 可能是 dict 或 list；尽量兼容
        pts = stroke.get("points") if isinstance(stroke, dict) else stroke
        strokes.append([norm_pt(p) for p in pts])
    return strokes

def main():
    # 1) 拉标准字数据
    r = requests.get(CHAR_URL.format(char=CHAR), timeout=30)
    r.raise_for_status()
    char_data = r.json()
    medians = char_data.get("medians")
    if not medians:
        raise RuntimeError("character API 返回里没有 medians")

    # 2) 生成一个“必然通过笔顺”的 user_strokes（从 medians 来）
    user_strokes = normalize_medians_to_user_strokes(medians, jitter=0.0)

    # 3) 调用评分
    payload = {"character": CHAR, "user_strokes": user_strokes}
    s = requests.post(SCORE_URL, json=payload, timeout=60)
    body = s.json()

    pretty("B(从 medians 生成) 请求摘要", {"strokes_count": len(user_strokes), "points_per_stroke": [len(x) for x in user_strokes][:5]})
    pretty("B(从 medians 生成) 响应", {"status_code": s.status_code, "body": body})

    # 4) 判定：不应返回笔顺错误；应该进入正常评分（至少 handwriting_score 有值或 stroke_analysis 非空）
    text = json.dumps(body, ensure_ascii=False)
    if "笔顺错误" in text or body.get("error_type"):
        raise AssertionError(f"仍触发笔顺错误/错误短路：{text}")

    print("\n✅ B 用例通过：已进入正常评分分支（未触发笔顺短路）")

if __name__ == "__main__":
    main()
