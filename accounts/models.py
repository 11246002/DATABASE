from django.db import models

class User(models.Model):
    user_name = models.CharField(max_length=50)
    password = models.CharField(max_length=255)
    role = models.CharField(max_length=20, default='user')
    created_at = models.DateField(auto_now_add=True)

    def __str__(self):
        return self.user_name
    

class Group(models.Model):
    group_name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.group_name
    

class GroupMember(models.Model):
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    joined_at = models.DateTimeField(auto_now_add=True)
    invite_code = models.CharField(max_length=10, unique=True)

    def __str__(self):
        return f"{self.user} in {self.group}"
