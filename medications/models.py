from django.db import models
from accounts.models import User


class Drug(models.Model):
    license = models.CharField(max_length=100)
    med_ch = models.CharField(max_length=100)
    med_en = models.CharField(max_length=100, blank=True, null=True)
    color = models.CharField(max_length=50, blank=True, null=True)
    shape = models.CharField(max_length=50, blank=True, null=True)
    indications = models.TextField(blank=True, null=True)
    element = models.TextField(blank=True, null=True)
    dosage_form = models.CharField(max_length=50, blank=True, null=True)


class Prescription(models.Model):
    prescription_id = models.AutoField(primary_key=True)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE
    )

    hospital_name = models.CharField(max_length=50)

    visit_date = models.DateTimeField()

    image = models.ImageField(
    upload_to='prescriptions/',
    null=True,
    blank=True
)

    def __str__(self):
        return f"{self.user.user_name} - {self.hospital_name}"


class DrugWarning(models.Model):
    warning_id = models.AutoField(primary_key=True)

    drug = models.ForeignKey(
        Drug,
        on_delete=models.CASCADE
    )

    conflict_target = models.CharField(max_length=255)

    warning_desc = models.TextField()

    def __str__(self):
        return f"{self.drug.med_ch} - {self.conflict_target}"
    

class PrescriptionDrug(models.Model):

    raw_name = models.CharField(max_length=255)

    total_amount = models.IntegerField()

    drug = models.ForeignKey(
        Drug,
        on_delete=models.SET_NULL, 
        null=True,
        blank=True
    )

    prescription = models.ForeignKey(
        Prescription,
        on_delete=models.CASCADE
    )

    frequency = models.CharField(max_length=20)

    days = models.IntegerField()

    remaining_amount = models.IntegerField(
        null=True,
        blank=True
    )

    def __str__(self):
        return f"藥單編號:{self.prescription.prescription_id},藥品編號:{self.id} - {self.raw_name} ({self.frequency})"
    

class Remind(models.Model):

    remind_id = models.AutoField(primary_key=True)

    prescription_drug = models.ForeignKey(
        PrescriptionDrug,
        on_delete=models.CASCADE
    )

    frequency_tag = models.CharField(max_length=50)

    remind_time = models.TimeField()

    def __str__(self):
        return f"{self.prescription_drug.raw_name} - {self.remind_time}"
    

class TakingRecord(models.Model):

    takingrecord_id = models.AutoField(primary_key=True)

    remind = models.ForeignKey(
        Remind,
        on_delete=models.CASCADE
    )

    status = models.CharField(max_length=20)

    taken_at = models.DateTimeField()

    def __str__(self):
        return f"{self.remind} - {self.status}"