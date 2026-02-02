# Agent Build Instructions

## Project Setup
```bash
# Install dependencies (example for Node.js project)
npm install

# Or for Python project
pip install -r requirements.txt

# Or for Rust project
cargo build
```

## Running Tests
```bash
# Node.js
npm test

# Python
pytest

# Rust
cargo test
```

## Build Commands
```bash
# Production build
npm run build
# or
cargo build --release
```

## Development Server
```bash
# Start development server
npm run dev
# or
cargo run
```

## Key Learnings
- Update this section when you learn new build optimizations
- Document any gotchas or special setup requirements
- Keep track of the fastest test/build cycle

## Feature Development Quality Standards

**CRITICAL**: All new features MUST meet the following mandatory requirements before being considered complete.

### Testing Requirements

- **Minimum Coverage**: 85% code coverage ratio required for all new code
- **Test Pass Rate**: 100% - all tests must pass, no exceptions
- **Test Types Required**:
  - Unit tests for all business logic and services
  - Integration tests for API endpoints or main functionality
  - End-to-end tests for critical user workflows
- **Coverage Validation**: Run coverage reports before marking features complete:
  ```bash
  # Examples by language/framework
  npm run test:coverage
  pytest --cov=src tests/ --cov-report=term-missing
  cargo tarpaulin --out Html
  ```
- **Test Quality**: Tests must validate behavior, not just achieve coverage metrics
- **Test Documentation**: Complex test scenarios must include comments explaining the test strategy

### Git Workflow Requirements

Before moving to the next feature, ALL changes must be:

1. **Committed with Clear Messages**:
   ```bash
   git add .
   git commit -m "feat(module): descriptive message following conventional commits"
   ```
   - Use conventional commit format: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, etc.
   - Include scope when applicable: `feat(api):`, `fix(ui):`, `test(auth):`
   - Write descriptive messages that explain WHAT changed and WHY

2. **Pushed to Remote Repository**:
   ```bash
   git push origin <branch-name>
   ```
   - Never leave completed features uncommitted
   - Push regularly to maintain backup and enable collaboration
   - Ensure CI/CD pipelines pass before considering feature complete

3. **Branch Hygiene**:
   - Work on feature branches, never directly on `main`
   - Branch naming convention: `feature/<feature-name>`, `fix/<issue-name>`, `docs/<doc-update>`
   - Create pull requests for all significant changes

4. **Ralph Integration**:
   - Update .ralph/@fix_plan.md with new tasks before starting work
   - Mark items complete in .ralph/@fix_plan.md upon completion
   - Update .ralph/PROMPT.md if development patterns change
   - Test features work within Ralph's autonomous loop

### Documentation Requirements

**ALL implementation documentation MUST remain synchronized with the codebase**:

1. **Code Documentation**:
   - Language-appropriate documentation (JSDoc, docstrings, etc.)
   - Update inline comments when implementation changes
   - Remove outdated comments immediately

2. **Implementation Documentation**:
   - Update relevant sections in this AGENT.md file
   - Keep build and test commands current
   - Update configuration examples when defaults change
   - Document breaking changes prominently

3. **README Updates**:
   - Keep feature lists current
   - Update setup instructions when dependencies change
   - Maintain accurate command examples
   - Update version compatibility information

4. **AGENT.md Maintenance**:
   - Add new build patterns to relevant sections
   - Update "Key Learnings" with new insights
   - Keep command examples accurate and tested
   - Document new testing patterns or quality gates

### 代码质量门槛 (NEW - Codex 集成)

在标记任何功能为完成前，以下**必须通过**：

#### 1. Pre-commit Codex 审查 (快速模式)

- **触发方式**: 自动在 `git commit` 时运行
- **检查内容**:
  - 语法错误
  - 代码风格 (black/dart format)
  - 导入语句规范
  - 基础安全问题
- **最长时间**: 30 秒
- **通过标准**: 无 error 或 warning
- **安装**:
  ```bash
  pip install pre-commit
  pre-commit install
  ```

#### 2. CI/CD 流水线

- **触发时机**: 推送到远程或创建 PR 时自动运行
- **检查内容**:
  - Backend: `pytest` (所有测试通过)
  - Frontend: `flutter test` (所有测试通过)
  - 覆盖率: >= 85%
  - Python: `ruff`, `black`, `mypy` 检查
  - Flutter: `flutter analyze` 检查
  - Codex 深度审查 (架构、安全、复杂度)

#### 3. PR 审批要求

- [ ] 所有 CI 检查通过
- [ ] Codex 深度审查完成 (无严重问题)
- [ ] 所有 Codex 反馈已解决
- [ ] 人工审批通过
- [ ] 覆盖率保持 >= 85%

### Feature Completion Checklist (更新版)

Before marking ANY feature as complete, verify:

- [ ] All tests pass with appropriate framework command
- [ ] Code coverage meets 85% minimum threshold
- [ ] Coverage report reviewed for meaningful test quality
- [ ] Code formatted according to project standards
- [ ] Type checking passes (if applicable)
- [ ] **Pre-commit Codex review passed** (NEW)
- [ ] All changes committed with conventional commit messages
- [ ] All commits pushed to remote repository
- [ ] **PR created with template** (NEW)
- [ ] **Codex deep review passed** (NEW)
- [ ] **All Codex feedback addressed** (NEW)
- [ ] .ralph/@fix_plan.md task marked as complete
- [ ] Implementation documentation updated
- [ ] Inline code comments updated or added
- [ ] .ralph/@AGENT.md updated (if new patterns introduced)
- [ ] Breaking changes documented
- [ ] Features tested within Ralph loop (if applicable)
- [ ] **CI/CD pipeline passes** (UPDATED with Codex review)
- [ ] **Human approval received** (NEW)

### Rationale

These standards ensure:
- **Quality**: High test coverage and pass rates prevent regressions
- **Traceability**: Git commits and .ralph/@fix_plan.md provide clear history of changes
- **Maintainability**: Current documentation reduces onboarding time and prevents knowledge loss
- **Collaboration**: Pushed changes enable team visibility and code review
- **Reliability**: Consistent quality gates maintain production stability
- **Automation**: Ralph integration ensures continuous development practices

**Enforcement**: AI agents should automatically apply these standards to all feature development tasks without requiring explicit instruction for each task.
