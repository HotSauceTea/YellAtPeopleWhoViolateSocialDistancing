# YellAtPeopleWhoViolateSocialDistancing

## Description

This is an app that computes the distance to other people, and if they come within 6 feet, it yells at them (with customizable yelling phrases).

There are two different distance detection methods. Here's how to use each (and how they work):
1. AR  
This works by using Apples Augmented Reality kit. This can detect people, then measure the distance to them. To use this, just point the phone in the general direction of people. The app will report the distance to the closest person.

2. Trig based  
To use this, point the + sign on the screen at the feet of the person that you want to measure the distance to. You also need to have input your height in the "Setup Data" screen. The app uses the angle of the phone, and the height that it's at (it assumes that you hold the phone at shoulder height, which is on average .82 of your full height).

## Warnings:
1. AR based distance detection is most accurate indoors and at close distances.
2. Trig based distance detection will not work well on unlevel ground

## Disclaimer
1. This is for entertainment only. It cannot prevent coronavirus. 

## Requirements:
1. iOS 13+
2. For AR distance mode, iphone with A12 Chip (iphone 11, XS, XS Max, XR) is required. Although Trig distance method will work for older phones. 

## Installation
1. Download the git repo
2. Open the project in XCode
3. Follow instructions here: https://codewithchris.com/xcode-tutorial/#10-ios-simulator For how to build the project on your phone
