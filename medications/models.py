from django.db import models

class Drug(models.Model):
    license = models.CharField(max_length=100)
    med_ch = models.CharField(max_length=100)
    med_en = models.CharField(max_length=100, blank=True, null=True)
    color = models.CharField(max_length=50, blank=True, null=True)
    shape = models.CharField(max_length=50, blank=True, null=True)
    indications = models.TextField(blank=True, null=True)
    element = models.TextField(blank=True, null=True)
    dosage_form = models.CharField(max_length=50, blank=True, null=True)
