# Build stage (stage 0)
FROM mcr.microsoft.com/dotnet/sdk:9.0

WORKDIR /app

# Install Git, CMake, and g++
RUN apt-get update && apt-get install -y git cmake g++ protobuf-compiler tree

# Clone gRPC
RUN git clone --recurse-submodules -b v1.66.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc /app/grpc

# Clone grpc-dotnet repository (create the directory first!)
RUN git clone --branch v2.67.0 --depth 1 https://github.com/grpc/grpc-dotnet /app/grpc-dotnet

#RUN tree /app/grpc-dotnet/examples

# Build protoc and grpc_csharp_plugin
RUN mkdir /app/grpc/build && \
    cd /app/grpc/build && \
    cmake /app/grpc && \
    make

# Copy the grpc_csharp_plugin to the correct location and make it executable
RUN cp /app/grpc/build/grpc_csharp_plugin /app/grpc-dotnet/examples/Greeter && \
    chmod +x /app/grpc-dotnet/examples/Greeter/grpc_csharp_plugin

RUN mkdir /app/grpc-dotnet/examples/Greeter/build
RUN mkdir /app/grpc-dotnet/examples/Greeter/build/gen

# Generate gRPC code (separate RUN instruction)
RUN protoc --proto_path=/app/grpc-dotnet/examples/Greeter/Proto \
           --csharp_out=/app/grpc-dotnet/examples/Greeter/build/gen \
		   --grpc_out=/app/grpc-dotnet/examples/Greeter/build/gen \
           --plugin=protoc-gen-grpc=/app/grpc-dotnet/examples/Greeter/grpc_csharp_plugin \
		   /app/grpc-dotnet/examples/Greeter/Proto/greet.proto

# Build the C# server application
WORKDIR /app/grpc-dotnet/examples/Greeter/Server
RUN dotnet build -c Release -o /app/out

# Runtime stage (stage 1)
FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

RUN mkdir -p /app/Protos # Create the directory

COPY --from=0 /app/grpc-dotnet/examples/Greeter/build/gen ./Protos
COPY --from=0 /app/out .

EXPOSE 50051

ENTRYPOINT ["dotnet", "Server.dll"]
