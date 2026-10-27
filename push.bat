@echo off
chcp 65001 >nul
echo ========================================================
echo 🚀 正在推送最新程式碼至 GitHub...
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/3] 加入最新修復遷移檔...
git add .
git commit -m "feat: 完善長輩逾時30分鐘推播與遷移檔設定" 2>nul

echo.
echo [2/3] 測試推播管線...
python test_fcm_push.py

echo.
echo [3/3] 推送到遠端 GitHub main 分支...
git push origin main

echo.
echo ========================================================
if %ERRORLEVEL% equ 0 (
    echo ✅ 推送成功！GitHub 已經是最新版本！
) else (
    echo ❌ 推送失敗，請查看上方具體紅字錯誤訊息。
)
echo ========================================================
pause
