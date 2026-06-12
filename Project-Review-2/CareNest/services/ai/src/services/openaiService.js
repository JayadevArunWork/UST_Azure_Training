const { OpenAIClient, AzureKeyCredential } = require("@azure/openai");
require('dotenv').config();

const endpoint = process.env.AZURE_OPENAI_ENDPOINT;
const apiKey = process.env.AZURE_OPENAI_KEY;

if (!endpoint || !apiKey) {
  console.warn("OpenAI endpoint or key is missing. Ensure they are set in environment.");
}

const client = new OpenAIClient(endpoint, new AzureKeyCredential(apiKey));

const SYMPTOM_DEPLOYMENT = process.env.GPT4O_DEPLOYMENT_NAME || 'gpt-4o';
const PRESCRIPTION_DEPLOYMENT = process.env.GPT4O_MINI_PRESCRIPTION_DEPLOYMENT || 'gpt-4o-mini-prescription';
const CHATBOT_DEPLOYMENT = process.env.GPT4O_MINI_CHATBOT_DEPLOYMENT || 'gpt-4o-mini-chatbot';

exports.analyzeSymptoms = async (symptomText, doctorData) => {
  const systemPrompt = `You are an AI medical assistant. Analyze the symptoms and return a JSON object with 'specialty', 'urgency' (low, medium, high), and 'reason'. Available doctors data: ${JSON.stringify(doctorData)}`;
  
  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: symptomText }
  ];

  const result = await client.getChatCompletions(SYMPTOM_DEPLOYMENT, messages, {
    responseFormat: { type: "json_object" },
    temperature: 0.3,
    maxTokens: 500
  });

  return JSON.parse(result.choices[0].message.content);
};

exports.summarizePrescription = async (prescriptionData) => {
  const systemPrompt = `You are a medical explainer. Convert the following clinical prescription data into a plain language, patient-friendly explanation. Keep it concise.`;
  
  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: JSON.stringify(prescriptionData) }
  ];

  const result = await client.getChatCompletions(PRESCRIPTION_DEPLOYMENT, messages, {
    temperature: 0.3,
    maxTokens: 300
  });

  return result.choices[0].message.content;
};

exports.answerPatientQuestion = async (question, patientContext) => {
  const systemPrompt = `You are a helpful healthcare chatbot for a patient. Answer the patient's question using ONLY the provided patient health context data (appointments, prescriptions, doctor notes). Do not make up information. Context: ${JSON.stringify(patientContext)}`;
  
  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: question }
  ];

  const result = await client.getChatCompletions(CHATBOT_DEPLOYMENT, messages, {
    temperature: 0.3,
    maxTokens: 400
  });

  return result.choices[0].message.content;
};
