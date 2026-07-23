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
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { DataTable, Column } from '@/components/data-table';
import { api } from '@/lib/api';
import { User, CreateUserByAdminInput, CreateUserByAdminResult } from '@/lib/types';
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
    queryFn: () => api.get('/admin/users').then((r) => r.data ?? []),
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

  const STORE_CATEGORIES = [
    { value: 'GROCERY', label: 'Продукты' },
    { value: 'CLOTHING', label: 'Одежда' },
    { value: 'ELECTRONICS', label: 'Электроника' },
    { value: 'HARDWARE', label: 'Хозтовары' },
    { value: 'PHARMACY', label: 'Аптека' },
    { value: 'OTHER', label: 'Другое' },
  ];

  const [createOpen, setCreateOpen] = useState(false);
  const [createName, setCreateName] = useState('');
  const [createPhone, setCreatePhone] = useState('');
  const [createEmail, setCreateEmail] = useState('');
  const [manualPassword, setManualPassword] = useState(false);
  const [createPassword, setCreatePassword] = useState('');
  const [createStore, setCreateStore] = useState(false);
  const [storeName, setStoreName] = useState('');
  const [storeCategory, setStoreCategory] = useState('');
  const [revealedPassword, setRevealedPassword] = useState<string | null>(null);

  const resetCreateForm = () => {
    setCreateName('');
    setCreatePhone('');
    setCreateEmail('');
    setManualPassword(false);
    setCreatePassword('');
    setCreateStore(false);
    setStoreName('');
    setStoreCategory('');
  };

  const createUserMutation = useMutation({
    mutationFn: (input: CreateUserByAdminInput) =>
      api.post('/admin/users', input) as Promise<CreateUserByAdminResult>,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      setCreateOpen(false);
      resetCreateForm();
      if (result.generatedPassword) {
        setRevealedPassword(result.generatedPassword);
      } else {
        toast.success('Пользователь создан');
      }
    },
    onError: (error: Error) => toast.error(error.message || 'Ошибка создания пользователя'),
  });

  const handleCreateSubmit = () => {
    const input: CreateUserByAdminInput = {
      name: createName,
      phone: createPhone,
      email: createEmail || undefined,
      password: manualPassword ? createPassword : undefined,
      createStore,
      storeName: createStore ? storeName : undefined,
      storeCategory: createStore ? storeCategory : undefined,
    };
    createUserMutation.mutate(input);
  };

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
        <span className="text-sm text-center block">{u._count?.ownedStores ?? 0}</span>
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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Пользователи</h1>
          <p className="text-muted-foreground text-sm mt-1">
            {users.length} пользователей всего
          </p>
        </div>
        <Button onClick={() => setCreateOpen(true)}>Создать пользователя</Button>
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

      {/* Create User Dialog */}
      <Dialog
        open={createOpen}
        onOpenChange={(open) => {
          setCreateOpen(open);
          if (!open) resetCreateForm();
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Создать пользователя</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <div className="space-y-2">
              <Label htmlFor="create-name">Имя</Label>
              <Input
                id="create-name"
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-phone">Телефон</Label>
              <Input
                id="create-phone"
                placeholder="+992XXXXXXXXX"
                value={createPhone}
                onChange={(e) => setCreatePhone(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-email">Email</Label>
              <Input
                id="create-email"
                type="email"
                value={createEmail}
                onChange={(e) => setCreateEmail(e.target.value)}
              />
            </div>

            <div className="flex items-center justify-between">
              <Label htmlFor="manual-password-switch">Ввести самому</Label>
              <Switch
                id="manual-password-switch"
                checked={manualPassword}
                onCheckedChange={(checked) => setManualPassword(checked as boolean)}
              />
            </div>
            {manualPassword && (
              <div className="space-y-2">
                <Label htmlFor="create-password">Пароль</Label>
                <Input
                  id="create-password"
                  type="text"
                  value={createPassword}
                  onChange={(e) => setCreatePassword(e.target.value)}
                />
              </div>
            )}
            {!manualPassword && (
              <p className="text-sm text-muted-foreground">
                Пароль будет сгенерирован автоматически и показан один раз после создания.
              </p>
            )}

            <div className="flex items-center justify-between">
              <Label htmlFor="create-store-switch">Создать магазин сразу</Label>
              <Switch
                id="create-store-switch"
                checked={createStore}
                onCheckedChange={(checked) => setCreateStore(checked as boolean)}
              />
            </div>
            {createStore && (
              <>
                <div className="space-y-2">
                  <Label htmlFor="store-name">Название магазина</Label>
                  <Input
                    id="store-name"
                    value={storeName}
                    onChange={(e) => setStoreName(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Категория</Label>
                  <Select value={storeCategory} onValueChange={(v) => v != null && setStoreCategory(v)}>
                    <SelectTrigger>
                      <SelectValue placeholder="Выберите категорию" />
                    </SelectTrigger>
                    <SelectContent>
                      {STORE_CATEGORIES.map((c) => (
                        <SelectItem key={c.value} value={c.value}>
                          {c.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>
              Отмена
            </Button>
            <Button onClick={handleCreateSubmit} disabled={createUserMutation.isPending}>
              Создать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* One-time generated password reveal */}
      <Dialog open={!!revealedPassword} onOpenChange={() => setRevealedPassword(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Пользователь создан</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Сохраните этот пароль — больше не будет показан.
            </p>
            <div className="flex items-center gap-2">
              <code className="flex-1 rounded-lg border border-input bg-transparent px-2.5 py-1.5 font-mono text-sm break-all">
                {revealedPassword}
              </code>
              <Button
                variant="outline"
                onClick={() => {
                  if (revealedPassword) {
                    navigator.clipboard.writeText(revealedPassword);
                    toast.success('Пароль скопирован');
                  }
                }}
              >
                Копировать
              </Button>
            </div>
          </div>
          <DialogFooter>
            <Button onClick={() => setRevealedPassword(null)}>Готово</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
