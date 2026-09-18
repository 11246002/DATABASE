from django.contrib import admin
from .models import (
    Drug,
    Prescription,
    PrescriptionDrug,
    DrugWarning,
    Remind,
    TakingRecord,
    MedicationHistory,
    PatientAllergy,
)

admin.site.register(Drug)
admin.site.register(Prescription)
admin.site.register(PrescriptionDrug)
admin.site.register(DrugWarning)
admin.site.register(Remind)
admin.site.register(TakingRecord)
admin.site.register(MedicationHistory)
admin.site.register(PatientAllergy)