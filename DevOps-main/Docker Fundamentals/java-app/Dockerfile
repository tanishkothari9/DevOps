# Use an official Eclipse Temurin (OpenJDK) runtime as the base image
FROM eclipse-temurin:21-jdk

# Set the working directory
WORKDIR /app

# Copy the Java source file
COPY Main.java ./

# Compile the Java program
RUN javac Main.java

# Expose the port the app runs on
EXPOSE 8080

# Command to run the compiled program
CMD ["java", "Main"]
