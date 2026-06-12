import StatusBadge from './StatusBadge';
import { Pill, User, Clock } from 'lucide-react';

export default function PrescriptionCard({ prescription, userRole, onUpdateStatus }) {
  return (
    <div className="group rounded-2xl border border-slate-200 bg-white p-6 shadow-sm hover:shadow-lg hover:border-teal-200 transition-all duration-300">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
            <Pill className="h-5 w-5" />
          </div>
          <div>
            <h3 className="font-semibold text-slate-800">
              {userRole === 'patient'
                ? `Dr. ${prescription.doctorName}`
                : prescription.patientName}
            </h3>
            <p className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
              <Clock className="h-3 w-3" />
              {new Date(prescription.createdAt).toLocaleDateString()}
            </p>
          </div>
        </div>
        <StatusBadge status={prescription.status} />
      </div>

      {/* Medications list */}
      <div className="space-y-2 mb-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
          Medications
        </p>
        <div className="space-y-2">
          {prescription.medications.map((med, i) => (
            <div
              key={i}
              className="rounded-xl bg-slate-50 p-3 text-sm"
            >
              <p className="font-medium text-slate-700">{med.name}</p>
              <p className="text-slate-500 text-xs mt-1">
                {med.dosage} · {med.frequency} · {med.duration}
              </p>
            </div>
          ))}
        </div>
      </div>

      {prescription.notes && (
        <p className="text-sm text-slate-500 italic mb-4">"{prescription.notes}"</p>
      )}

      {/* Actions */}
      {prescription.status === 'pending' && (
        <div className="flex gap-2 border-t border-slate-100 pt-4">
          <button
            onClick={() => onUpdateStatus(prescription._id, 'dispensed')}
            className="rounded-lg bg-emerald-50 px-4 py-2 text-sm font-medium text-emerald-700 hover:bg-emerald-100 transition-colors"
          >
            Mark Dispensed
          </button>
          <button
            onClick={() => onUpdateStatus(prescription._id, 'cancelled')}
            className="rounded-lg bg-red-50 px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-100 transition-colors"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  );
}
