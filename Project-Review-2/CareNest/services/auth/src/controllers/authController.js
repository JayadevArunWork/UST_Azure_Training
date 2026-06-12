const { validationResult } = require('express-validator');
const authService = require('../services/authService');

const register = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const { user, token } = await authService.register(req.body);
    res.status(201).json({ message: 'User registered successfully', user, token });
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
};

const { verifyEntraToken } = require('../middleware/entraAuth');
const jwt = require('jsonwebtoken'); // Assuming JWT local signing is needed
const User = require('../models/User'); // Mongoose model to save entra user

const login = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return verifyEntraToken(req, res, async () => {
      // Create local token to match existing flow
      const token = jwt.sign({ id: req.user.id, role: req.user.role }, process.env.JWT_SECRET, { expiresIn: '1d' });
      // Upsert user in db
      await User.findOneAndUpdate(
        { email: req.user.email },
        { _id: req.user.id, email: req.user.email, name: req.user.email.split('@')[0], role: req.user.role },
        { upsert: true, new: true }
      );
      return res.json({ message: 'Login successful via Entra', user: req.user, token });
    });
  }

  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const { email, password } = req.body;
    const { user, token } = await authService.login(email, password);
    res.json({ message: 'Login successful', user, token });
  } catch (error) {
    res.status(401).json({ message: error.message });
  }
};

const getProfile = async (req, res) => {
  try {
    const user = await authService.getProfile(req.user.id);
    res.json({ user });
  } catch (error) {
    res.status(404).json({ message: error.message });
  }
};

const getDoctors = async (req, res) => {
  try {
    const doctors = await authService.getDoctors();
    res.json({ doctors });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { register, login, getProfile, getDoctors };
