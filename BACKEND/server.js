const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const cookieParser = require("cookie-parser");
require("dotenv").config();

const { router: userAuthRoutes } = require("./userAuth"); // ✅ Import userAuth.js routes
const vehicleRoutes = require("./vehicleRoutes");  // ✅ Import vehicle routes

const app = express();

// ✅ Middleware
app.use(express.json());
app.use(cookieParser());

// ✅ CORS Configuration (Allow Local & Netlify Frontend)
const allowedOrigins = [
  "http://localhost:3000",   // React Frontend
  "https://ukc-car-tracking-system.netlify.app", // React Production
  "http://10.0.2.2:3000",    // Flutter Emulator (Android)
  "http://127.0.0.1:3000"    // Flutter Web (if needed)
];


app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error("❌ Not allowed by CORS"));
      }
    },
    credentials: true, // ✅ Allow cookies & authentication headers
  })
);

// ✅ Connect to MongoDB
mongoose
  .connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.error("❌ MongoDB Connection Failed:", err));

// ✅ Use Routes from userAuth.js & vehicleRoutes.js
app.use("/api", userAuthRoutes); // 👈 User authentication routes
app.use("/api", vehicleRoutes);  // 👈 Vehicle tracking routes

// ✅ Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => console.log(`🚀 Server running on all network interfaces at port ${PORT}`));

