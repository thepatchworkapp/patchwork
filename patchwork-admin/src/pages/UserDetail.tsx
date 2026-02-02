import { useState } from "react";
import { useQuery } from "convex/react";
import { anyApi } from "convex/server";
import type { Id } from "../../../Patchwork_MCP/convex/_generated/dataModel";
import { 
  ChevronDown, 
  ChevronUp, 
  ChevronLeft, 
  MapPin, 
  Shield, 
  Star, 
  Briefcase, 
  MessageSquare,
  Ghost,
  Clock,
  CheckCircle,
  User,
  Mail
} from "lucide-react";

const api = anyApi as any;

const formatCurrency = (cents: number | undefined) => {
  if (cents === undefined) return "N/A";
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(cents / 100);
};

const formatDate = (timestamp: number) => {
  return new Date(timestamp).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
};

const Section = ({ title, children, defaultOpen = false, icon: Icon }: { title: string, children: React.ReactNode, defaultOpen?: boolean, icon?: any }) => {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  return (
    <div className="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden mb-4">
      <button 
        onClick={() => setIsOpen(!isOpen)} 
        className="w-full px-6 py-4 flex items-center justify-between bg-slate-50 hover:bg-slate-100 transition-colors"
      >
        <div className="flex items-center gap-2 font-semibold text-slate-800">
            {Icon && <Icon size={18} className="text-slate-500" />}
            {title}
        </div>
        {isOpen ? <ChevronUp size={20} className="text-slate-400" /> : <ChevronDown size={20} className="text-slate-400" />}
      </button>
      {isOpen && <div className="p-6 border-t border-slate-200">{children}</div>}
    </div>
  );
};

interface UserDetailProps {
  userId: Id<"users">;
  onBack: () => void;
}

export function UserDetail({ userId, onBack }: UserDetailProps) {
    const data = useQuery(api.admin.getUserDetail, { userId });
    
    const photoUrl = useQuery(api.files.getUrl, data?.user?.photo ? { storageId: data.user.photo } : "skip");

    if (!data) {
        return (
            <div className="p-8 flex justify-center">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            </div>
        );
    }

    if (!data.user) {
        return (
            <div className="p-8 text-center">
                <p className="text-red-600">User not found</p>
                <button onClick={onBack} className="mt-4 text-indigo-600 hover:underline">Go Back</button>
            </div>
        );
    }

    const { user, seekerProfile, taskerProfile, jobsAsSeeker, jobsAsTasker, reviewsGiven, reviewsReceived } = data;

    return (
        <div className="max-w-5xl mx-auto p-6">
            <div className="mb-6">
                <button 
                    onClick={onBack}
                    className="flex items-center text-slate-500 hover:text-slate-800 mb-4 transition-colors"
                >
                    <ChevronLeft size={20} className="mr-1" />
                    Back to User List
                </button>
                
                <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex flex-col md:flex-row gap-6 items-center md:items-start">
                    <div className="relative">
                        <div className="w-24 h-24 rounded-full bg-slate-200 overflow-hidden flex items-center justify-center text-2xl font-bold text-slate-500 border-4 border-white shadow-md">
                            {photoUrl ? (
                                <img src={photoUrl} alt={user.name} className="w-full h-full object-cover" />
                            ) : (
                                user.name.charAt(0).toUpperCase()
                            )}
                        </div>
                    </div>
                    
                    <div className="flex-1 text-center md:text-left">
                        <h1 className="text-2xl font-bold text-slate-900">{user.name}</h1>
                        <div className="flex items-center justify-center md:justify-start gap-2 text-slate-500 mt-1">
                            <Mail size={16} />
                            <span>{user.email}</span>
                            {user.emailVerified && <CheckCircle size={14} className="text-green-500" />}
                        </div>
                        
                        <div className="flex flex-wrap gap-2 mt-4 justify-center md:justify-start">
                             {user.roles.isSeeker && (
                                <span className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium">Seeker</span>
                             )}
                             {user.roles.isTasker && (
                                <span className="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-full text-sm font-medium">Tasker</span>
                             )}
                             {taskerProfile?.subscriptionPlan === "premium" && (
                                <span className="px-3 py-1 bg-amber-100 text-amber-700 rounded-full text-sm font-medium flex items-center gap-1">
                                    <Star size={12} className="fill-amber-700" /> Premium
                                </span>
                             )}
                        </div>
                    </div>
                    
                    <div className="text-right text-sm text-slate-500">
                        <p>Joined {formatDate(user.createdAt)}</p>
                        <p className="mt-1">ID: <span className="font-mono text-xs bg-slate-100 px-1 rounded">{user._id}</span></p>
                    </div>
                </div>
            </div>

            <Section title="Basic Info" defaultOpen icon={User}>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                        <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3">Location</h3>
                        <div className="flex items-center gap-2">
                            <MapPin size={18} className="text-slate-400" />
                            <span className="text-slate-900">{user.location.city}, {user.location.province}</span>
                        </div>
                        {user.location.coordinates && (
                            <p className="text-xs text-slate-400 ml-7 mt-1">
                                Lat: {user.location.coordinates.lat.toFixed(4)}, Lng: {user.location.coordinates.lng.toFixed(4)}
                            </p>
                        )}
                    </div>
                    <div>
                        <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3">Settings</h3>
                        <div className="space-y-2">
                            <div className="flex items-center justify-between">
                                <span className="text-slate-700">Notifications</span>
                                <span className={user.settings.notificationsEnabled ? "text-green-600" : "text-red-600"}>
                                    {user.settings.notificationsEnabled ? "Enabled" : "Disabled"}
                                </span>
                            </div>
                            <div className="flex items-center justify-between">
                                <span className="text-slate-700">Location Services</span>
                                <span className={user.settings.locationEnabled ? "text-green-600" : "text-red-600"}>
                                    {user.settings.locationEnabled ? "Enabled" : "Disabled"}
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
            </Section>

            {user.roles.isSeeker && seekerProfile && (
                <Section title="Seeker Profile" icon={Briefcase}>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <div className="bg-slate-50 p-4 rounded-lg text-center">
                            <div className="text-2xl font-bold text-slate-900">{seekerProfile.jobsPosted}</div>
                            <div className="text-sm text-slate-500">Jobs Posted</div>
                        </div>
                        <div className="bg-slate-50 p-4 rounded-lg text-center">
                            <div className="text-2xl font-bold text-slate-900">{seekerProfile.completedJobs}</div>
                            <div className="text-sm text-slate-500">Jobs Completed</div>
                        </div>
                        <div className="bg-slate-50 p-4 rounded-lg text-center">
                            <div className="text-2xl font-bold text-slate-900 flex items-center justify-center gap-1">
                                {seekerProfile.rating.toFixed(1)} <Star size={16} className="text-yellow-400 fill-yellow-400" />
                            </div>
                            <div className="text-sm text-slate-500">Rating ({seekerProfile.ratingCount})</div>
                        </div>
                        <div className="bg-slate-50 p-4 rounded-lg text-center">
                            <div className="text-2xl font-bold text-slate-900">{seekerProfile.favouriteTaskers.length}</div>
                            <div className="text-sm text-slate-500">Favorite Taskers</div>
                        </div>
                    </div>
                </Section>
            )}

            {user.roles.isTasker && taskerProfile && (
                <Section title="Tasker Profile" icon={Shield}>
                    <div className="mb-6">
                        <div className="flex justify-between items-start">
                            <div>
                                <h3 className="text-xl font-bold text-slate-900">{taskerProfile.displayName}</h3>
                                <p className="text-slate-600 mt-1">{taskerProfile.bio || "No bio provided"}</p>
                            </div>
                             <div className="flex flex-col gap-2 items-end">
                                {taskerProfile.ghostMode && (
                                    <span className="flex items-center gap-1 px-3 py-1 bg-slate-800 text-white rounded-full text-xs">
                                        <Ghost size={12} /> Ghost Mode
                                    </span>
                                )}
                                {taskerProfile.premiumPin && (
                                    <span className="text-xs text-slate-500 font-mono">PIN: {taskerProfile.premiumPin}</span>
                                )}
                             </div>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
                            <div className="bg-slate-50 p-4 rounded-lg text-center">
                                <div className="text-xl font-bold text-slate-900 capitalize">{taskerProfile.subscriptionPlan}</div>
                                <div className="text-sm text-slate-500">Plan</div>
                            </div>
                            <div className="bg-slate-50 p-4 rounded-lg text-center">
                                <div className="text-xl font-bold text-slate-900 flex items-center justify-center gap-1">
                                    {taskerProfile.rating.toFixed(1)} <Star size={16} className="text-yellow-400 fill-yellow-400" />
                                </div>
                                <div className="text-sm text-slate-500">Rating ({taskerProfile.reviewCount})</div>
                            </div>
                             <div className="bg-slate-50 p-4 rounded-lg text-center">
                                <div className="text-xl font-bold text-slate-900">{taskerProfile.completedJobs}</div>
                                <div className="text-sm text-slate-500">Jobs Completed</div>
                            </div>
                             <div className="bg-slate-50 p-4 rounded-lg text-center">
                                <div className="text-xl font-bold text-slate-900">{taskerProfile.verified ? "Yes" : "No"}</div>
                                <div className="text-sm text-slate-500">Verified</div>
                            </div>
                        </div>
                    </div>

                    <h3 className="font-semibold text-slate-900 mb-4 border-b pb-2">Service Categories</h3>
                    <div className="space-y-4">
                        {taskerProfile.categories.map((cat: any, idx: number) => (
                            <div key={idx} className="bg-slate-50 rounded-lg p-4">
                                <div className="flex justify-between items-start mb-2">
                                    <h4 className="font-bold text-indigo-700">{cat.categoryName}</h4>
                                    <div className="text-right">
                                        <span className="font-bold text-slate-900">
                                            {cat.rateType === "hourly" ? formatCurrency(cat.hourlyRate) + "/hr" : formatCurrency(cat.fixedRate) + " flat"}
                                        </span>
                                        <p className="text-xs text-slate-500">{cat.serviceRadius}km radius</p>
                                    </div>
                                </div>
                                <p className="text-sm text-slate-600 mb-3">{cat.bio}</p>
                                <div className="flex gap-4 text-sm text-slate-500">
                                    <span className="flex items-center gap-1"><Star size={14} className="fill-slate-400"/> {cat.rating.toFixed(1)} ({cat.reviewCount})</span>
                                    <span>{cat.completedJobs} jobs</span>
                                </div>
                            </div>
                        ))}
                        {taskerProfile.categories.length === 0 && (
                             <p className="text-slate-500 italic">No categories configured.</p>
                        )}
                    </div>
                </Section>
            )}

            <Section title="Job History" icon={Clock}>
                <div className="space-y-6">
                    {user.roles.isSeeker && jobsAsSeeker && jobsAsSeeker.length > 0 && (
                        <div>
                            <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3">Recent Jobs as Seeker</h3>
                             <div className="overflow-x-auto">
                                <table className="w-full text-sm text-left">
                                    <thead className="bg-slate-100 text-slate-600">
                                        <tr>
                                            <th className="px-3 py-2 rounded-l-lg">Date</th>
                                            <th className="px-3 py-2">Category</th>
                                            <th className="px-3 py-2">Status</th>
                                            <th className="px-3 py-2 rounded-r-lg">Amount</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100">
                                        {jobsAsSeeker.map((job: any) => (
                                            <tr key={job._id}>
                                                <td className="px-3 py-2 text-slate-600">{formatDate(job.createdAt)}</td>
                                                <td className="px-3 py-2 font-medium">{job.categoryName}</td>
                                                <td className="px-3 py-2">
                                                    <span className={`px-2 py-0.5 rounded-full text-xs uppercase font-semibold ${
                                                        job.status === 'completed' ? 'bg-green-100 text-green-700' :
                                                        job.status === 'cancelled' ? 'bg-red-100 text-red-700' :
                                                        'bg-blue-100 text-blue-700'
                                                    }`}>
                                                        {job.status.replace('_', ' ')}
                                                    </span>
                                                </td>
                                                <td className="px-3 py-2 text-slate-900">{formatCurrency(job.rate)}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {user.roles.isTasker && jobsAsTasker && jobsAsTasker.length > 0 && (
                        <div>
                             <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3 mt-4">Recent Jobs as Tasker</h3>
                             <div className="overflow-x-auto">
                                <table className="w-full text-sm text-left">
                                    <thead className="bg-slate-100 text-slate-600">
                                        <tr>
                                            <th className="px-3 py-2 rounded-l-lg">Date</th>
                                            <th className="px-3 py-2">Category</th>
                                            <th className="px-3 py-2">Status</th>
                                            <th className="px-3 py-2 rounded-r-lg">Amount</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100">
                                        {jobsAsTasker.map((job: any) => (
                                            <tr key={job._id}>
                                                <td className="px-3 py-2 text-slate-600">{formatDate(job.createdAt)}</td>
                                                <td className="px-3 py-2 font-medium">{job.categoryName}</td>
                                                <td className="px-3 py-2">
                                                    <span className={`px-2 py-0.5 rounded-full text-xs uppercase font-semibold ${
                                                        job.status === 'completed' ? 'bg-green-100 text-green-700' :
                                                        job.status === 'cancelled' ? 'bg-red-100 text-red-700' :
                                                        'bg-blue-100 text-blue-700'
                                                    }`}>
                                                        {job.status.replace('_', ' ')}
                                                    </span>
                                                </td>
                                                <td className="px-3 py-2 text-slate-900">{formatCurrency(job.rate)}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                     {(!jobsAsSeeker?.length && !jobsAsTasker?.length) && (
                        <p className="text-slate-500 italic">No job history available.</p>
                    )}
                </div>
            </Section>

            <Section title="Reviews" icon={MessageSquare}>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                         <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3">Reviews Received</h3>
                         <div className="space-y-4">
                            {reviewsReceived && reviewsReceived.map((review: any) => (
                                <div key={review._id} className="bg-slate-50 p-3 rounded-lg">
                                    <div className="flex justify-between items-start mb-1">
                                        <span className="font-medium text-slate-900">{review.reviewerName}</span>
                                        <span className="text-xs text-slate-400">{formatDate(review.createdAt)}</span>
                                    </div>
                                    <div className="flex items-center gap-1 mb-2">
                                        {Array.from({ length: 5 }).map((_, i) => (
                                            <Star key={i} size={12} className={i < review.rating ? "text-yellow-400 fill-yellow-400" : "text-slate-300"} />
                                        ))}
                                    </div>
                                    <p className="text-sm text-slate-600 italic">"{review.text}"</p>
                                </div>
                            ))}
                             {(!reviewsReceived || reviewsReceived.length === 0) && (
                                <p className="text-sm text-slate-400 italic">No reviews received.</p>
                            )}
                         </div>
                    </div>
                    
                    <div>
                         <h3 className="text-sm font-semibold text-slate-500 uppercase mb-3">Reviews Given</h3>
                         <div className="space-y-4">
                            {reviewsGiven && reviewsGiven.map((review: any) => (
                                <div key={review._id} className="bg-slate-50 p-3 rounded-lg">
                                    <div className="flex justify-between items-start mb-1">
                                        <span className="font-medium text-slate-900">To: {review.revieweeName}</span>
                                        <span className="text-xs text-slate-400">{formatDate(review.createdAt)}</span>
                                    </div>
                                    <div className="flex items-center gap-1 mb-2">
                                        {Array.from({ length: 5 }).map((_, i) => (
                                            <Star key={i} size={12} className={i < review.rating ? "text-yellow-400 fill-yellow-400" : "text-slate-300"} />
                                        ))}
                                    </div>
                                    <p className="text-sm text-slate-600 italic">"{review.text}"</p>
                                </div>
                            ))}
                             {(!reviewsGiven || reviewsGiven.length === 0) && (
                                <p className="text-sm text-slate-400 italic">No reviews given.</p>
                            )}
                         </div>
                    </div>
                </div>
            </Section>
        </div>
    );
}
