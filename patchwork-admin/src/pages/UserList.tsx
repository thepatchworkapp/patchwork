import { useState } from 'react';
import { useQuery } from 'convex/react';
// Use anyApi to avoid type-checking the backend files which causes build errors
// due to stricter config in this project or missing types in the backend files.
import { anyApi } from 'convex/server';
import { Search, User, Mail, Calendar, ChevronDown, Loader2 } from 'lucide-react';

const api = anyApi as any;

interface UserListProps {
  onSelectUser: (userId: string) => void;
}

export function UserList({ onSelectUser }: UserListProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [limit, setLimit] = useState(20);
  
  const data = useQuery(api.admin.listAllUsers, { limit });
  const users = data?.users || [];
  const isLoading = data === undefined;

  // Client-side filtering
  const filteredUsers = users.filter((user: any) => {
    const query = searchQuery.toLowerCase();
    return (
      user.name.toLowerCase().includes(query) ||
      user.email.toLowerCase().includes(query)
    );
  });

  const handleLoadMore = () => {
    setLimit((prev) => prev + 20);
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Users</h1>
        <p className="text-slate-400">Manage and view all users in the system</p>
      </div>

      {/* Search Bar */}
      <div className="mb-6 relative">
        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <Search className="h-5 w-5 text-slate-400" />
        </div>
        <input
          type="text"
          placeholder="Search users by name or email..."
          className="block w-full pl-10 pr-3 py-3 border border-slate-700 rounded-lg leading-5 bg-slate-800 text-slate-200 placeholder-slate-500 focus:outline-none focus:bg-slate-700 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 sm:text-sm transition-colors"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      {/* Content */}
      <div className="bg-slate-800 rounded-xl border border-slate-700 overflow-hidden shadow-xl">
        {isLoading ? (
          <div className="p-12 flex flex-col items-center justify-center text-slate-400">
            <Loader2 className="h-10 w-10 animate-spin mb-4 text-indigo-500" />
            <p>Loading users...</p>
          </div>
        ) : filteredUsers.length === 0 ? (
          <div className="p-12 text-center text-slate-400">
            <User className="h-12 w-12 mx-auto mb-4 opacity-20" />
            <p className="text-lg">No users found</p>
            <p className="text-sm opacity-60">Try adjusting your search terms</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-700">
              <thead className="bg-slate-900/50">
                <tr>
                  <th scope="col" className="px-6 py-4 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    User
                  </th>
                  <th scope="col" className="px-6 py-4 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Roles
                  </th>
                  <th scope="col" className="px-6 py-4 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Location
                  </th>
                  <th scope="col" className="px-6 py-4 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Joined
                  </th>
                  <th scope="col" className="px-6 py-4 text-right text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700 bg-slate-800">
                {filteredUsers.map((user: any) => (
                  <tr 
                    key={user._id} 
                    onClick={() => onSelectUser(user._id)}
                    className="hover:bg-slate-700/50 transition-colors cursor-pointer group"
                  >
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="flex-shrink-0 h-10 w-10">
                          {user.photo ? (
                            <img className="h-10 w-10 rounded-full object-cover border-2 border-slate-600" src={user.photo} alt="" />
                          ) : (
                            <div className="h-10 w-10 rounded-full bg-slate-600 flex items-center justify-center border-2 border-slate-500">
                              <span className="text-sm font-medium text-white">
                                {user.name?.charAt(0).toUpperCase() || '?'}
                              </span>
                            </div>
                          )}
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-white group-hover:text-indigo-300 transition-colors">
                            {user.name}
                          </div>
                          <div className="text-sm text-slate-400 flex items-center gap-1">
                            <Mail className="h-3 w-3" />
                            {user.email}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex flex-wrap gap-2">
                        {user.roles?.isSeeker && (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-900/30 text-blue-400 border border-blue-800">
                            Seeker
                          </span>
                        )}
                        {user.roles?.isTasker && (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-900/30 text-emerald-400 border border-emerald-800">
                            Tasker
                          </span>
                        )}
                        {!user.roles?.isSeeker && !user.roles?.isTasker && (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-700 text-slate-400">
                            None
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-300">
                      {user.location ? (
                        <div className="flex items-center gap-1">
                          <span>{user.location.city}, {user.location.province}</span>
                        </div>
                      ) : (
                        <span className="text-slate-500 italic">Unknown</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-400">
                      <div className="flex items-center gap-1">
                        <Calendar className="h-3 w-3" />
                        {new Date(user.createdAt).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <span className="text-indigo-400 group-hover:text-indigo-300">View</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        
        {/* Footer / Pagination */}
        {users.length > 0 && (
          <div className="bg-slate-900/30 px-6 py-4 border-t border-slate-700 flex items-center justify-between">
            <div className="text-sm text-slate-400">
              Showing <span className="font-medium text-white">{filteredUsers.length}</span> of <span className="font-medium text-white">{users.length}</span> loaded
            </div>
            
            {/* 
              If the backend returns a cursor, it means there are more users.
              Our `limit` strategy fetches N users. If we got N users, likely more exist.
              (Strictly we should check data.cursor, but for this simple UI, a "Load More" button 
              that appears if we have a full page is fine, or just always show it if not empty)
            */}
            {data?.cursor && (
              <button
                onClick={handleLoadMore}
                className="inline-flex items-center px-4 py-2 border border-slate-600 rounded-md shadow-sm text-sm font-medium text-slate-200 bg-slate-800 hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                Load More
                <ChevronDown className="ml-2 -mr-1 h-4 w-4" />
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
