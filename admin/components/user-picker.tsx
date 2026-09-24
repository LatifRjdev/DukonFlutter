'use client';

import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { Input } from '@/components/ui/input';

interface PickerUser {
  id: string;
  name: string;
  phone: string;
}

export function UserPicker({
  value,
  onSelect,
  placeholder = 'Поиск по имени или телефону...',
}: {
  value: string;
  onSelect: (id: string, label: string) => void;
  placeholder?: string;
}) {
  const [search, setSearch] = useState(value);

  // Same client-side-filter-over-the-full-list approach the Users list page
  // (admin/app/(admin)/users/page.tsx) already uses for its own search box —
  // not a new server-side query, and no new dependency for a dropdown widget.
  const { data: users = [] } = useQuery<PickerUser[]>({
    queryKey: ['users'],
    queryFn: () => api.get('/admin/users').then((r) => r.data ?? []),
  });

  const matches = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return users
      .filter((u) => u.name?.toLowerCase().includes(q) || u.phone.includes(q))
      .slice(0, 8);
  }, [search, users]);

  return (
    <div className="relative">
      <Input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder={placeholder}
      />
      {matches.length > 0 && (
        <div className="absolute z-10 mt-1 w-full rounded-md border bg-popover shadow-md">
          {matches.map((u) => (
            <button
              key={u.id}
              type="button"
              className="block w-full px-3 py-2 text-left text-sm hover:bg-muted"
              onClick={() => {
                onSelect(u.id, u.name);
                setSearch(u.name);
              }}
            >
              {u.name}{' '}
              <span className="text-muted-foreground">{u.phone}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
