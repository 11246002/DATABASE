import time
import sys
from django.core.management.base import BaseCommand
from django.utils import timezone
from accounts.notifications import check_and_send_overdue_alerts


class Command(BaseCommand):
    help = '每分鐘定時掃描長輩服藥狀態，逾時 30 分鐘自動跨手機推播給家庭成員'

    def add_arguments(self, parser):
        parser.add_argument(
            '--interval',
            type=int,
            default=60,
            help='排程檢查間隔秒數 (預設 60 秒)'
        )
        parser.add_argument(
            '--once',
            action='store_true',
            help='僅執行單次掃描後立即退出 (適合 Cron 或測試)'
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='強制忽略已發送日誌 (展場展示測試用)'
        )

    def handle(self, *args, **options):
        interval = options['interval']
        run_once = options['once']
        force = options['force']

        self.stdout.write(self.style.SUCCESS(
            f"=======================================================\n"
            f"🚀 [智慧藥管家] 逾時服藥跨手機推播排程引擎已啟動\n"
            f"⏱️ 檢查頻率: 每 {interval} 秒掃描一次\n"
            f"🎯 模式: {'單次掃描' if run_once else '常駐監控'}\n"
            f"======================================================="
        ))

        iteration = 0
        while True:
            iteration += 1
            now_str = timezone.localtime().strftime('%Y-%m-%d %H:%M:%S')
            self.stdout.write(f"[{now_str}] (第 {iteration} 次) 正在掃描長輩服藥狀態...")

            try:
                res = check_and_send_overdue_alerts(force=force)
                scanned = res.get('scanned_reminds', 0)
                triggered = res.get('alerts_triggered', 0)

                if triggered > 0:
                    self.stdout.write(self.style.WARNING(
                        f"  ⚠️ 發現 {triggered} 筆逾時未服藥！已成功發送推播給家屬！"
                    ))
                else:
                    self.stdout.write(self.style.SUCCESS(
                        f"  ✓ 掃描完成 (共檢查 {scanned} 筆提醒)，無新增逾時項目。"
                    ))

            except Exception as e:
                self.stdout.write(self.style.ERROR(f"  ❌ 掃描過程發生錯誤: {e}"))

            if run_once:
                self.stdout.write(self.style.SUCCESS("單次掃描完成，已退出。"))
                break

            try:
                time.sleep(interval)
            except KeyboardInterrupt:
                self.stdout.write(self.style.NOTICE("\n收到停止訊號 (Ctrl+C)，排程引擎已安全終止。"))
                sys.exit(0)
