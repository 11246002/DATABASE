from django.contrib import admin
from .models import Drug, Prescription, PrescriptionDrug, DrugWarning, Remind, TakingRecord

admin.site.register(Drug)
admin.site.register(Prescription)
admin.site.register(PrescriptionDrug)
admin.site.register(DrugWarning)
admin.site.register(Remind)
admin.site.register(TakingRecord)