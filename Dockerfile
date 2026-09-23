# DeFi lending protocol (Solidity + Hardhat). The product is the smart contracts;
# there is no Python service in this repo.
FROM node:20-slim
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund || npm install --no-audit --no-fund
COPY . .
# Compile contracts and run the test suite
RUN npx hardhat compile
CMD ["npx", "hardhat", "test"]
