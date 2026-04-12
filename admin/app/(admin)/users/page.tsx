'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { MoreHorizontal, Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { DataTable, Column } from '@/components/data-table';
import { api } from '@/lib/api';
import { User } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

type Filter = 'all' | 'admin' | 'blocked';

export default function UsersPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<Filter>('all');

  const { data: users = [], isLoading } = useQuery<User[]>({
    queryKey: ['users'],
    queryFn: () => api.get('/admin/users'),
  });

  const toggleAdminMutation = useMutation({
    mutationFn: (userId: string) => api.put(`/admin/users/${userId}/toggle-admin`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      toast.success('Роль пользователя обновлена');
    },
    onError: () => toast.error('Ошибка обновления роли'),
  });

  const toggleBlockMutation = useMutation({
    mutationFn: (user: User) =>
      api.put(`/admin/users/${user.id}/${user.isActive ? 'block' : 'unblock'}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      toast.success('Статус пользователя обновлён');
    },
    onError: () => toast.error('Ошибка обновления статуса'),
  });

  const filtered = users.filter((u) => {
    const matchesSearch =
      !search ||
      u.name?.toLowerCase().includes(search.toLowerCase()) ||
      u.phone.includes(search) ||
      u.email?.toLowerCase().includes(search.toLowerCase());
    const matchesFilter =
      filter === 'all' ||
      (filter === 'admin' && u.isAdmin) ||
      (filter === 'blocked' && !u.isActive);
    return matchesSearch && matchesFilter;
  });

  const columns: Column<User>[] = [
    {
      key: 'name',
      header: 'Имя',
      cell: (u) => <span className="font-medium">{u.name || '—'}</span>,
    },
    {
      key: 'phone',
      header: 'Телефон',
      cell: (u) => <span className="font-mono text-sm">{u.phone}</span>,
    },
    {
      key: 'email',
      header: 'Email',
      cell: (u) => <span className="text-sm">{u.email || '—'}</span>,
    },
    {
      key: 'stores',
      header: 'Магазины',
      cell: (u) => (
        <span className="text-sm text-center block">{u.storeCount ?? 0}</span>
      ),
    },
    {
      key: 'isAdmin',
      header: 'Роль',
      cell: (u) =>
        u.isAdmin ? (
          <Badge className="bg-blue-100 text-blue-800 hover:bg-blue-100">
            Админ
          </Badge>
        ) : (
          <Badge variant="outline">Пользователь</Badge>
        ),
    },
    {
      key: 'isActive',
      header: 'Статус',
      cell: (u) =>
        u.isActive ? (
          <Badge className="bg-green-100 text-green-800 hover:bg-green-100">
            Активен
          </Badge>
        ) : (
          <Badge className="bg-red-100 text-red-800 hover:bg-red-100">
            Заблокирован
          </Badge>
        ),
    },
    {
      key: 'createdAt',
      header: 'Зарегистрирован',
      cell: (u) => (
        <span className="text-sm text-muted-foreground">
          {u.createdAt ? format(new Date(u.createdAt), 'dd.MM.yyyy') : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      cell: (u) => (
        <DropdownMenu>
          <DropdownMenuTrigger
            onClick={(e) => e.stopPropagation()}
            className="inline-flex h-7 w-7 items-center justify-center rounded hover:bg-muted"
          >
            <MoreHorizontal className="h-4 w-4" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem
              onClick={(e) => {
                e.stopPropagation();
                toggleAdminMutation.mutate(u.id);
              }}
            >
              {u.isAdmin ? 'Снять права admin' : 'Сделать admin'}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={(e) => {
                e.stopPropagation();
                toggleBlockMutation.mutate(u);
              }}
              className={u.isActive ? 'text-red-600' : 'text-green-600'}
            >
              {u.isActive ? 'Заблокировать' : 'Разблокировать'}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
      className: 'w-12',
    },
  ];

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Пользователи</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {users.length} пользователей всего
        </p>
      </div>

      <div className="flex items-center gap-3">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Поиск по имени, телефону, email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex gap-2">
          {(['all', 'admin', 'blocked'] as Filter[]).map((f) => (
            <Button
              key={f}
              variant={filter === f ? 'default' : 'outline'}
              size="sm"
              onClick={() => setFilter(f)}
            >
              {f === 'all' ? 'Все' : f === 'admin' ? 'Администраторы' : 'Заблокированные'}
            </Button>
          ))}
        </div>
      </div>

      <DataTable
        data={filtered}
        columns={columns}
        isLoading={isLoading}
        onRowClick={(u) => router.push(`/users/${u.id}`)}
        emptyMessage="Пользователи не найдены"
      />
    </div>
  );
}
