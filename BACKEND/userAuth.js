const mongoose = require("mongoose");
const express = require("express");
const bcrypt = require("bcrypt");

const jwt = require("jsonwebtoken");
const cors = require("cors");
require("dotenv").config();

const router = express.Router();
const app = express();

// Middleware
app.use(express.json());
app.use(cors({ origin: true, credentials: true }));

// List of allowed roles
const allowedRoles = [
  "Admin",
  "Security Guard",
  "Active Reception Technician",
  "Service Advisor",
  "Job Controller",
  "Bay Technician",
  "Final Inspection Technician",
  "Diagnosis Engineer",
  "Washing",
];

// MongoDB User Schema
const UserSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    mobile: { type: String, unique: true, required: true },
    email: { type: String, unique: true, sparse: true }, // Optional email
    password: { type: String, required: true }, // Hashed password
    role: { type: String, enum: allowedRoles, required: true }, // Fixed role selection
  },
  { timestamps: true }
);

const User = mongoose.model("User", UserSchema);

// JWT Middleware
const authMiddleware = (req, res, next) => {
  const token = req.header("Authorization")?.replace("Bearer ", ""); // Read token from Authorization header
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified;
    next();
  } catch (error) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

router.post("/register", async (req, res) => {
  try {
    const { name, mobile, email, password, role } = req.body;

    // Validate input
    if (!name || !mobile || !password || !allowedRoles.includes(role)) {
      return res.status(400).json({ message: "Invalid input data." });
    }

    if (typeof password !== "string") {
      return res.status(400).json({ message: "Password must be a string." });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ mobile });
    if (existingUser) {
      return res.status(400).json({ message: "User with this mobile already registered" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, Number(10));

    // Create new user
    const newUser = new User({ name, mobile, email, password: hashedPassword, role });
    await newUser.save();

    res.status(201).json({ success: true, message: "User registered successfully" });
  } catch (error) {
    console.error("Registration Error:", error);
    res.status(500).json({ 
      success: false, 
      message: "Server error", 
      error: error.message || error 
    });
  }
});



// Login API (Only Mobile & Role Required)
router.post("/login", async (req, res) => {
  try {
    const { mobile, role } = req.body;

    // Find user by Mobile and Role
    const user = await User.findOne({ mobile, role });
    if (!user) {
      return res.status(404).json({ message: "User not found. Please check your details." });
    }

    // Generate JWT
    const token = jwt.sign(
      { userId: user._id, name: user.name, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // Return token in response
    res.json({ success: true, token, user: { name: user.name, role: user.role } });
  } catch (error) {
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

// Logout API
router.post("/logout", (req, res) => {
  // Since we're not using cookies, logout is handled client-side by removing the token
  res.json({ success: true, message: "Logged out successfully" });
});

// ✅ Get All Users (Admin Access)
router.get("/users", authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== "Admin") {
      return res.status(403).json({ message: "Access Denied. Admins only." });
    }

    const users = await User.find({}, "-password"); // Exclude passwords
    res.json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

// Export everything
module.exports = { router, authMiddleware, User };