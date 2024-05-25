## Technologies Used
- MongoDB
- Express.js
- React
- Node.js
- Docker
- AWS (Amazon Web Services)
- GitHub Actions
- Terraform

## Local Setup

### Prerequisites
- Node.js and npm installed
- MongoDB installed and running
- Docker installed

### Steps
1. Clone the repository: `git clone <repository_url>`
2. Install dependencies:
   bash
   cd project-directory
   npm install
   
3. Configure the environment variables:
   - Create a `.env` file in the project's root directory.
   - Define the necessary environment variables, such as database connection details, API keys, etc.

4. Start the backend server:
   bash
   npm run start:server
   

5. Start the frontend development server:
   bash
   npm run start:client
   

6. Access the application in your browser at `http://localhost:3000`.

## Deployment on AWS

### Prerequisites
- AWS account with appropriate permissions
- Docker Hub account

### Steps

1. Set up an AWS account and create an IAM user with the necessary permissions for EC2, S3, and other required services.

2. Configure AWS CLI with the IAM user credentials on your local machine:
   bash
   aws configure
   

3. Create a Docker Hub account and set up a repository.

4. Update the necessary configuration files:
   - `.github/workflows/main.yml`: Replace the Docker Hub repository details and AWS credentials.
   - `terraform/main.tf`: Customize the AWS infrastructure resources as per your requirements.

5. Deploy the infrastructure using Terraform:
   bash
   cd terraform
   terraform init
   terraform apply
   

6. Trigger the CI/CD pipeline by pushing changes to the repository.

7. Access the deployed application using the provided AWS resources, such as the load balancer URL.

