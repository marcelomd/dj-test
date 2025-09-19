from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    return HttpResponse("Hello, World! This is my first Django app.")


def about(request):
    context = {'title': 'About Page'}
    return render(request, 'myapp/about.html', context)
