# Generated manually for DeviceToken and OverdueNotificationLog

import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_devicetoken_overduenotificationlog'),
        ('medications', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='DeviceToken',
            fields=[
                ('device_token_id', models.AutoField(primary_key=True, serialize=False)),
                ('fcm_token', models.CharField(max_length=255, unique=True)),
                ('platform', models.CharField(default='android', max_length=20)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='device_tokens', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': '裝置推播 Token',
                'verbose_name_plural': '裝置推播 Token 列表',
            },
        ),
        migrations.CreateModel(
            name='OverdueNotificationLog',
            fields=[
                ('log_id', models.AutoField(primary_key=True, serialize=False)),
                ('record_date', models.DateField(default=django.utils.timezone.localdate)),
                ('sent_at', models.DateTimeField(auto_now_add=True)),
                ('remind', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='overdue_logs', to='medications.remind')),
            ],
            options={
                'verbose_name': '逾時服藥推播日誌',
                'verbose_name_plural': '逾時服藥推播日誌列表',
            },
        ),
        migrations.AddConstraint(
            model_name='overduenotificationlog',
            constraint=models.UniqueConstraint(fields=('remind', 'record_date'), name='unique_remind_overdue_log_per_day'),
        ),
    ]
