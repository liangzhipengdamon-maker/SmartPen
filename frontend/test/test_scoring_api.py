import json
import requests

BASE_URL = "http://127.0.0.1:8000"
HEALTH_URL = f"{BASE_URL}/api/score/health"
API_URL = f"{BASE_URL}/api/score/comprehensive"

CHAR = "永"

def pretty(title: str, obj):
    print(f"\n=== {title} ===")
    print(json.dumps(obj, ensure_ascii=False, indent=2))

def call(payload):
    r = requests.post(API_URL, json=payload, timeout=30)
    try:
        body = r.json()
    except Exception:
        body = {"raw": r.text}
    return r.status_code, body

def assert_p0_3_mismatch(body):
    """
    P0-3 预期：笔画数不匹配 -> 直接“笔顺错误”并短路 DTW
    你们实现里提到：feedback='笔顺错误' + error_type='stroke_count_mismatch'
    字段名可能略有差异，所以这里做“宽松但有效”的判定。
    """
    text = json.dumps(body, ensure_ascii=False)

    # 必须包含“笔顺错误”
    if "笔顺错误" not in text:
        raise AssertionError(f"期望包含 '笔顺错误'，但实际返回：{text}")

    # error_type 期望（若你们没返回该字段，也允许，但会提示）
    if "stroke_count_mismatch" not in text and "error_type" not in text:
        print("⚠️ 警告：返回中未发现 error_type / stroke_count_mismatch（如果你们设计就是只返回 feedback，可忽略）")

    # 短路 DTW：通常会让 score=0 或不返回详细 dtw 字段
    if isinstance(body, dict):
        score = body.get("score", None)
        if score is not None and score != 0 and score != 0.0:
            print(f"⚠️ 警告：score 不是 0（score={score}）。如果你们设计允许 score 字段但应为 0，请检查。")
    return True

def assert_success_path(status_code, body):
    # 成功路径：至少应该是 200
    if status_code != 200:
        raise AssertionError(f"期望 200，但得到 {status_code}，body={body}")

def main():
    print("Running P0-3 scoring tests...\n")

    # 0) health check
    try:
        h = requests.get(HEALTH_URL, timeout=10)
        print("Health status:", h.status_code, h.text[:200])
    except Exception as e:
        raise SystemExit(f"无法访问 health: {e}")

    # A) 笔画数不匹配：只给 2 笔
    payload_mismatch = {
        "character": CHAR,
        "user_strokes": [
            [[0.10, 0.10], [0.20, 0.20], [0.30, 0.30]],
            [[0.20, 0.40], [0.25, 0.45], [0.30, 0.50]],
        ],
        # posture_data 可省略
    }
    sc_a, body_a = call(payload_mismatch)
    pretty("测试 A：笔画数不匹配", {"status_code": sc_a, "body": body_a})

    # A1) 判定是否满足 P0-3
    if sc_a not in (200, 400, 422):
        print("⚠️ 非预期状态码（但仍继续检查 body）:", sc_a)
    assert_p0_3_mismatch(body_a)
    print("✅ 测试 A：满足 P0-3（笔画数不匹配 -> 笔顺错误短路）")

    # B) 笔画数匹配：给 5 笔（永字通常 5 笔；即使轨迹不准也应进入正常评分流程）
    payload_match = {
        "character": CHAR,
        "user_strokes": [
            [[0.10, 0.10], [0.20, 0.20]],
            [[0.20, 0.30], [0.25, 0.35]],
            [[0.30, 0.40], [0.35, 0.45]],
            [[0.40, 0.50], [0.45, 0.55]],
            [[0.50, 0.60], [0.55, 0.65]],
        ],
    }
    sc_b, body_b = call(payload_match)
    pretty("测试 B：笔画数匹配", {"status_code": sc_b, "body": body_b})

    # B1) 成功路径应为 200（若后端对轨迹太短太假也可能 422/400，你贴出来我再帮你调长轨迹）
    assert_success_path(sc_b, body_b)

    # 不应返回笔画数不匹配的错误
    text_b = json.dumps(body_b, ensure_ascii=False)
    if "stroke_count_mismatch" in text_b or "笔顺错误" in text_b:
        raise AssertionError(f"匹配用例不应返回笔顺/笔画数错误，但实际：{text_b}")

    print("✅ 测试 B：正常进入评分流程（未触发笔画数短路）")

    print("\nAll done. P0-3 backend gate looks good ✅")

if __name__ == "__main__":
    main()
