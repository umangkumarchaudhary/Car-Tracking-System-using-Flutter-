const express = require("express");
const router = express.Router();
const Vehicle = require("./models/vehicle");

// ✅ 1️⃣ POST: Handle Vehicle Check-in and Stage Updates
router.post("/vehicle-check", async (req, res) => {
  console.log("🔹 Incoming Request Data:", req.body);

  try {
    const { vehicleNumber, role, stageName, eventType, inKM, outKM, inDriver, outDriver, workType, bayNumber } = req.body;

    if (!vehicleNumber || !role || !stageName || !eventType) {
      console.log("❌ Missing required fields");
      return res.status(400).json({ success: false, message: "Required fields are missing." });
    }

    const formattedVehicleNumber = vehicleNumber.trim().toUpperCase();

    // ✅ Check if Vehicle Exists
    let vehicle = await Vehicle.findOne({ vehicleNumber: formattedVehicleNumber }).sort({ entryTime: -1 });

    // ✅ Case 1: New Vehicle Entry
    if (!vehicle) {
      vehicle = new Vehicle({
        vehicleNumber: formattedVehicleNumber,
        entryTime: new Date(),
        exitTime: null, // Exit time starts as null
        stages: [
          {
            stageName,
            role,
            eventType,
            timestamp: new Date(),
            inKM: role === "Security Guard" && eventType === "Start" ? inKM : null,
            outKM: role === "Security Guard" && eventType === "End" ? outKM : null,
            inDriver: role === "Security Guard" && eventType === "Start" ? inDriver : null,
            outDriver: role === "Security Guard" && eventType === "End" ? outDriver : null,
            workType: role === "Bay Technician" && eventType === "Start" ? workType || null : null,
            bayNumber: role === "Bay Technician" && eventType === "Start" ? bayNumber || null : null,
          },
        ],
      });

      await vehicle.save();
      return res.status(201).json({ success: true, newVehicle: true, message: "New vehicle entry recorded.", vehicle });
    }

    // ✅ Get latest event for the given stage
    const relatedStages = vehicle.stages.filter(stage => stage.stageName === stageName);
    const lastStage = relatedStages.length > 0 ? relatedStages[relatedStages.length - 1] : null;

    // ✅ Case 2: Update Existing Vehicle Entry
    if (eventType === "Start") {
      if (lastStage && lastStage.eventType === "End") {
        console.log(`❌ Cannot restart ${stageName} for ${formattedVehicleNumber}, it has already been completed.`);
        return res.status(400).json({ success: false, message: `Cannot restart ${stageName}. It has already been completed.` });
      }

      if (lastStage && lastStage.eventType === "Start") {
        console.log(`❌ ${stageName} has already started for ${formattedVehicleNumber}`);
        return res.status(400).json({ success: false, message: `${stageName} has already started. Complete it before starting again.` });
      }

      // ✅ Store `inKM` and `inDriver` correctly inside the existing vehicle's `stages` array
      vehicle.stages.push({
        stageName,
        role,
        eventType: "Start",
        timestamp: new Date(),
        inKM: role === "Security Guard" ? inKM : null,
        inDriver: role === "Security Guard" ? inDriver : null,
        workType: role === "Bay Technician" ? workType || null : null,
        bayNumber: role === "Bay Technician" ? bayNumber || null : null,
      });

      await vehicle.save();
      return res.status(200).json({ success: true, message: `${stageName} started.`, vehicle });
    }

    if (eventType === "End") {
      if (!lastStage || lastStage.eventType !== "Start") {
        console.log(`❌ ${stageName} was not started for ${formattedVehicleNumber}, cannot end.`);
        return res.status(400).json({ success: false, message: `${stageName} was not started.` });
      }

      // ✅ Prevent multiple "End" events within 10 seconds
      const timeDifference = (new Date() - new Date(lastStage.timestamp)) / 1000; // Convert to seconds
      if (timeDifference < 10) {
        console.log(`❌ Wait at least 10 seconds before completing ${stageName} for ${formattedVehicleNumber}.`);
        return res.status(400).json({ success: false, message: `Wait at least 10 seconds before completing ${stageName}.` });
      }

      // ✅ Store `outKM` and `outDriver` when Security Guard exits the vehicle
      vehicle.stages.push({
        stageName,
        role,
        eventType: "End",
        timestamp: new Date(),
        outKM: role === "Security Guard" ? outKM : null,
        outDriver: role === "Security Guard" ? outDriver : null,
      });

      // ✅ Update exitTime **ONLY** if Security Guard marks "End"
      if (role === "Security Guard" && stageName === "Security Gate") {
        vehicle.exitTime = new Date();
      }

      await vehicle.save();
      return res.status(200).json({ success: true, message: `${stageName} completed.`, vehicle });
    }

    console.log(`❌ Invalid event type received for ${formattedVehicleNumber}`);
    return res.status(400).json({ success: false, message: "Invalid event type." });

  } catch (error) {
    console.error("❌ Error in /vehicle-check:", error);
    return res.status(500).json({ success: false, message: "Server error", error });
  }
});


// ✅ 2️⃣ GET: Fetch All Vehicles & Their Full Journey
router.get("/vehicles", async (req, res) => {

  try {
    const vehicles = await Vehicle.find().sort({ entryTime: -1 });

    if (vehicles.length === 0) {
      return res.status(404).json({ success: false, message: "No vehicles found." });
    }

    return res.status(200).json({ success: true, vehicles });
  } catch (error) {
    console.error("❌ Error in GET /vehicles:", error);
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

// ✅ 3️⃣ GET: Fetch Single Vehicle Journey by Vehicle Number
router.get("/vehicles/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const formattedVehicleNumber = vehicleNumber.trim().toUpperCase();

    const vehicle = await Vehicle.findOne({ vehicleNumber: formattedVehicleNumber }).sort({ entryTime: -1 });

    if (!vehicle) {
      return res.status(404).json({ success: false, message: "Vehicle not found." });
    }

    return res.status(200).json({ success: true, vehicle });
  } catch (error) {
    console.error("❌ Error in GET /vehicles/:vehicleNumber:", error);
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

router.get("/vehicles/bay-allocation-in-progress", async (req, res) => {
  try {
    const vehicles = await Vehicle.find({
      "stages.stageName": "Bay Allocation Started",
    });

    return res.json({ success: true, vehicles });
  } catch (error) {
    console.error("Error fetching vehicles in progress:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});




router.get("/finished-interactive-bay", async (req, res) => {
  try {
    const vehicles = await Vehicle.find().sort({ entryTime: -1 });

    // Filter vehicles that have both "Start" and "End" for "Interactive Bay"
    const filteredVehicles = vehicles.filter(vehicle => {
      const interactiveBayStages = vehicle.stages.filter(stage => stage.stageName === "Interactive Bay");
      
      const hasStart = interactiveBayStages.some(stage => stage.eventType === "Start");
      const hasEnd = interactiveBayStages.some(stage => stage.eventType === "End");

      return hasStart && hasEnd; // Return only if both Start and End exist
    });

    if (filteredVehicles.length === 0) {
      return res.status(404).json({ success: false, message: "No vehicles found with completed Interactive Bay." });
    }

    return res.status(200).json({ success: true, vehicles: filteredVehicles });
  } catch (error) {
    console.error("❌ Error in GET /finished-interactive-bay:", error);
    res.status(500).json({ success: false, message: "Server error", error });
  }
});


router.get("/vehicles/interactive-started", async (req, res) => {
  try {
    console.log("➡️ Fetching Interactive Bay Started Vehicles...");

    // Log the exact query being used
    const query = {
      "stages.stageName": "Interactive Bay",
      "stages.eventType": "Start"
    };

    console.log("🔎 Query:", JSON.stringify(query, null, 2));

    // Execute the query
    const vehicles = await Vehicle.find(query);

    console.log("✅ Found Vehicles:", vehicles);

    if (vehicles.length === 0) {
      console.log("❌ No matching vehicles found");
      return res.status(404).json({
        success: false,
        message: "Vehicle not found.",
        query, // Send the query back to debug it
        existingVehicles: await Vehicle.find(), // Send existing data to see why it's not matching
      });
    }

    res.json({ success: true, vehicles });
  } catch (error) {
    console.error("❌ Error fetching started Interactive Bay vehicles:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching started Interactive Bay vehicles",
      error: error.message
    });
  }
});








// ✅ 4️⃣ DELETE: Remove All Vehicles (For Testing/Resetting Data)
router.delete("/vehicles", async (req, res) => {
  try {
    await Vehicle.deleteMany();
    return res.status(200).json({ success: true, message: "All vehicle records deleted." });
  } catch (error) {
    console.error("❌ Error in DELETE /vehicles:", error);
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

module.exports = router;