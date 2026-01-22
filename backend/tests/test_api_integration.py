"""
API 集成测试脚本

测试所有 API 端点的功能
"""
import requests
from typing import Optional
import json


class APITester:
    """API 测试器"""

    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()

    def _print_result(self, name: str, success: bool, message: str = ""):
        """打印测试结果"""
        status = "✓" if success else "✗"
        color = "\033[92m" if success else "\033[91m"
        reset = "\033[0m"
        print(f"{color}{status}{reset} {name}")
        if message:
            print(f"  {message}")

    def test_health(self) -> bool:
        """测试健康检查"""
        try:
            response = self.session.get(f"{self.base_url}/health")
            success = response.status_code == 200
            self._print_result("健康检查", success, f"状态码: {response.status_code}")
            return success
        except Exception as e:
            self._print_result("健康检查", False, str(e))
            return False

    def test_get_character(self, char: str = "永") -> bool:
        """测试获取字符数据"""
        try:
            response = self.session.get(f"{self.base_url}/api/characters/{char}")
            success = response.status_code == 200
            if success:
                data = response.json()
                self._print_result(
                    f"获取字符 '{char}'",
                    True,
                    f"笔画数: {len(data.get('strokes', []))}"
                )
            else:
                self._print_result(
                    f"获取字符 '{char}'",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result(f"获取字符 '{char}'", False, str(e))
            return False

    def test_score_strokes(self, char: str = "永") -> bool:
        """测试笔画评分"""
        try:
            # 模拟笔画数据
            payload = {
                "character": char,
                "user_strokes": [
                    [[0.5, 0.3], [0.5, 0.5], [0.5, 0.7]],
                    [[0.3, 0.5], [0.5, 0.5], [0.7, 0.5]],
                ],
                "mode": "basic",
            }

            response = self.session.post(
                f"{self.base_url}/api/characters/score",
                json=payload
            )

            success = response.status_code == 200
            if success:
                data = response.json()
                score = data.get('total_score', 0)
                self._print_result(
                    f"笔画评分 '{char}'",
                    True,
                    f"得分: {score}/100"
                )
            else:
                self._print_result(
                    f"笔画评分 '{char}'",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result(f"笔画评分 '{char}'", False, str(e))
            return False

    def test_custom_characters(self) -> bool:
        """测试自定义范字"""
        try:
            # 获取范字列表
            response = self.session.get(f"{self.base_url}/api/custom-characters/")
            success = response.status_code == 200

            if success:
                data = response.json()
                total = data.get('total', 0)
                self._print_result(
                    "获取自定义范字列表",
                    True,
                    f"总数: {total}"
                )
            else:
                self._print_result(
                    "获取自定义范字列表",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result("获取自定义范字列表", False, str(e))
            return False

    def test_create_custom_character(self) -> bool:
        """测试创建自定义范字"""
        try:
            payload = {
                "char": "测",
                "style": "kaishu",
                "strokes": [
                    {"points": [[0.5, 0.3], [0.5, 0.7]], "order": 0},
                    {"points": [[0.3, 0.5], [0.7, 0.5]], "order": 1},
                ],
                "creator_id": "test_user",
                "creator_name": "测试用户",
                "tags": ["测试"],
                "is_public": False,
            }

            response = self.session.post(
                f"{self.base_url}/api/custom-characters/",
                json=payload
            )

            success = response.status_code in [200, 201]
            if success:
                data = response.json()
                self._print_result(
                    "创建自定义范字",
                    True,
                    f"ID: {data.get('id')}"
                )
            else:
                self._print_result(
                    "创建自定义范字",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result("创建自定义范字", False, str(e))
            return False

    def test_user_progress_summary(self) -> bool:
        """测试用户进度汇总"""
        try:
            response = self.session.get(
                f"{self.base_url}/api/user-progress/summary",
                params={"user_id": "user_0001"}
            )

            success = response.status_code == 200
            if success:
                data = response.json()
                total = data.get('total_practices', 0)
                avg = data.get('average_score', 0)
                self._print_result(
                    "用户进度汇总",
                    True,
                    f"练习: {total}次, 平均: {avg:.1f}分"
                )
            else:
                self._print_result(
                    "用户进度汇总",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result("用户进度汇总", False, str(e))
            return False

    def test_leaderboard(self) -> bool:
        """测试排行榜"""
        try:
            response = self.session.get(f"{self.base_url}/api/user-progress/leaderboard")
            success = response.status_code == 200

            if success:
                data = response.json()
                count = len(data)
                self._print_result(
                    "排行榜",
                    True,
                    f"返回 {count} 条记录"
                )
            else:
                self._print_result(
                    "排行榜",
                    False,
                    f"状态码: {response.status_code}"
                )
            return success
        except Exception as e:
            self._print_result("排行榜", False, str(e))
            return False

    def run_all_tests(self) -> dict:
        """运行所有测试"""
        results = {
            "passed": 0,
            "failed": 0,
            "tests": []
        }

        tests = [
            ("健康检查", self.test_health),
            ("获取字符数据", self.test_get_character),
            ("笔画评分", self.test_score_strokes),
            ("自定义范字列表", self.test_custom_characters),
            ("创建自定义范字", self.test_create_custom_character),
            ("用户进度汇总", self.test_user_progress_summary),
            ("排行榜", self.test_leaderboard),
        ]

        print("=" * 50)
        print("SmartPen API 集成测试")
        print("=" * 50)
        print(f"测试服务器: {self.base_url}")
        print()

        for name, test_func in tests:
            try:
                success = test_func()
                results["tests"].append((name, success))
                if success:
                    results["passed"] += 1
                else:
                    results["failed"] += 1
            except Exception as e:
                self._print_result(name, False, str(e))
                results["tests"].append((name, False))
                results["failed"] += 1

        print()
        print("=" * 50)
        print("测试结果汇总")
        print("=" * 50)
        print(f"总计: {results['passed'] + results['failed']} 个测试")
        print(f"✓ 通过: {results['passed']}")
        print(f"✗ 失败: {results['failed']}")
        print(f"成功率: {results['passed'] / (results['passed'] + results['failed']) * 100:.1f}%")

        return results


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description='API 集成测试')
    parser.add_argument(
        '--url',
        type=str,
        default='http://localhost:8000',
        help='API 服务器地址'
    )

    args = parser.parse_args()

    tester = APITester(base_url=args.url)
    tester.run_all_tests()


if __name__ == "__main__":
    main()
