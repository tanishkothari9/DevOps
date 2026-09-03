# Use an official Node.js runtime as the base image
FROM node:20-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and install dependencies (none here, but good practice)
COPY package.json ./
RUN npm install

# Copy the application code
COPY app.js ./

# Expose the port the app runs on
EXPOSE 3000

# Command to start the app
CMD ["npm", "start"]
