# TrashcanSensor
### Project for COMPSCI 147 (University of California, Irvine)

### Folders
#### terraform
- The infrastructure needed to run the API and the dashboard. 
- Run this first (production) in order to use this project.
    - The Terraform configuration will need to be altered to use
    the proper backend.
      
#### api
- Contains the Flask API that manages the flow of information between
the sensor and humans.
  
#### dashboard
- A simple React application that pulls the sensor information from the API
and displays it for a user to be able to see.
  
#### TrashcanSensor
- The Arduino code that runs the sensor for the project.
- The `server` variable would need to be changed to reflect the 
IP address of the deployed API.