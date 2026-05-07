# AHLMS | Automated Hardware Lifecycle Management System by Gabriel Perez

## Why I Built This
I built this project because I saw how much time was being wasted on manual data entry in IT asset management. Technicians were manually typing long serial numbers from hardware labels into spreadsheets, which led to constant typos and broken audit trails. I wanted to build a "point-and-shoot" solution where the data flows directly from the hardware into the cloud without anyone having to type a single character.

## How It Works
* Computer Vision & AI: I integrated AWS Rekognition to handle the heavy lifting. Instead of fighting with a standard barcode scanner that won't focus, my app takes a snapshot and uses AI to read the text and serial numbers off the label automatically.
* Serverless Backend: The whole system runs on AWS Lambda and API Gateway. It’s fast, scales automatically, and doesn't cost anything to sit idle.
* ServiceNow Integration: I wrote a Python integration that talks to the ServiceNow REST API. As soon as a device is scanned, it automatically creates a compliance ticket in ServiceNow with all the asset details.
* Automated Logging: Every scan is instantly saved to Amazon DynamoDB, creating a permanent, searchable log of every piece of hardware I've processed.
* Infrastructure as Code: I didn't want to click around the AWS console, so I defined the entire environment in Terraform. I can spin up the whole backend—database, API, and permissions—with a single command.

## Tech Stack
* Cloud: AWS (Lambda, API Gateway, DynamoDB, IAM)
* AI: AWS Rekognition (Computer Vision)
* ITSM: ServiceNow API
* DevOps: Terraform (Infrastructure as Code)
* Languages: Python, JavaScript, HTML/CSS

## Purpose & Compliance
I designed this to solve real-world compliance gaps. By automating the data entry, the system ensures a 100% accurate "Chain of Custody" that meets strict hardware sanitization standards like DoD 5220.22-M.
