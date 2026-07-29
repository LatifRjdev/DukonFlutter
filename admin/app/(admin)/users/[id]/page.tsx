'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Store, ShieldCheck, ShieldOff, Ban, CheckCircle, Send } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { api } from '@/lib/api';
import { User, Store as StoreType } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

export default function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data: user, isLoading } = useQuery<User>({
    queryKey: ['user', id],
    queryFn: () => api.get(`/admin/users/${id}`),
  });

  const { data: stores = [] } = useQuery<StoreType[]>({
    queryKey: ['user-stores', id],
    queryFn: () => api.get(`/admin/users/${id}/stores`),
  });

  const toggleAdminMutation = useMutation({
    mutationFn: () => api.put(`/admin/users/${id}/toggle-admin`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', id] });
      toast.success('Роль пользователя обновлена');
    },
    onError: () => toast.error('Ошибка обновления роли'),
  });

  const toggleBlockMutation = useMutation({
    mutationFn: () =>
      api.put(`/admin/users/${id}/${user?.isActive ? 'block' : 'unblock'}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', id] });
      toast.success('Статус пользователя обновлён');
    },
    onError: () => toast.error('Ошибка обновления статуса'),
  });

  const [messageDialog, setMessageDialog] = useState(false);
  const [msgTitle, setMsgTitle] = useState('');
  const [msgBody, setMsgBody] = useState('');

  const sendMessageMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/notifications/direct', { userId: id, title: msgTitle, body: msgBody }),
    onSuccess: () => {
      setMessageDialog(false);
      setMsgTitle('');
      setMsgBody('');
      toast.success('Сообщение отправлено');
    },
    onError: () => toast.error('Ошибка отправки сообщения'),
  });

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="h-8 w-48 animate-pulse rounded bg-slate-100" />
        <div className="h-48 animate-pulse rounded bg-slate-100" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="text-center py-12">
        <p className="text-muted-foreground">Пользователь не найден</p>
        <Button variant="outline" onClick={() => router.back()} className="mt-4">
          Назад
        </Button>
      </div>
    );
  }

  const initials = user.name
    ? user.name
        .split(' ')
        .map((n) => n[0])
        .join('')
        .toUpperCase()
        .slice(0, 2)
    : user.phone.slice(-2);

  return (
    <div className="space-y-6 max-w-3xl">
      <Button variant="ghost" onClick={() => router.back()} className="-ml-2">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Назад
      </Button>

      {/* Profile Card */}
      <Card>
        <CardHeader>
          <CardTitle>Профиль пользователя</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-start gap-6">
            <Avatar className="h-16 w-16">
              <AvatarFallback className="text-lg bg-blue-100 text-blue-700">
                {initials}
              </AvatarFallback>
            </Avatar>
            <div className="flex-1 space-y-4">
              <div>
                <h2 className="text-xl font-semibold">{user.name || '—'}</h2>
                <p className="text-muted-foreground font-mono">{user.phone}</p>
                {user.email && (
                  <p className="text-muted-foreground text-sm">{user.email}</p>
                )}
              </div>
              <div className="flex gap-2">
                {user.isAdmin && (
                  <Badge className="bg-blue-100 text-blue-800 hover:bg-blue-100">
                    <ShieldCheck className="mr-1 h-3 w-3" />
                    Администратор
                  </Badge>
                )}
                {user.isActive ? (
                  <Badge className="bg-green-100 text-green-800 hover:bg-green-100">
                    <CheckCircle className="mr-1 h-3 w-3" />
                    Активен
                  </Badge>
                ) : (
                  <Badge className="bg-red-100 text-red-800 hover:bg-red-100">
                    <Ban className="mr-1 h-3 w-3" />
                    Заблокирован
                  </Badge>
                )}
              </div>
              <p className="text-sm text-muted-foreground">
                Зарегистрирован:{' '}
                {user.createdAt
                  ? format(new Date(user.createdAt), 'dd.MM.yyyy')
                  : '—'}
              </p>
            </div>
          </div>

          <Separator className="my-4" />

          <div className="flex gap-3">
            <Button
              variant="outline"
              onClick={() => toggleAdminMutation.mutate()}
              disabled={toggleAdminMutation.isPending}
            >
              {user.isAdmin ? (
                <>
                  <ShieldOff className="mr-2 h-4 w-4" />
                  Снять права admin
                </>
              ) : (
                <>
                  <ShieldCheck className="mr-2 h-4 w-4" />
                  Сделать admin
                </>
              )}
            </Button>
            <Button
              variant={user.isActive ? 'destructive' : 'outline'}
              onClick={() => toggleBlockMutation.mutate()}
              disabled={toggleBlockMutation.isPending}
            >
              {user.isActive ? (
                <>
                  <Ban className="mr-2 h-4 w-4" />
                  Заблокировать
                </>
              ) : (
                <>
                  <CheckCircle className="mr-2 h-4 w-4" />
                  Разблокировать
                </>
              )}
            </Button>
            <Button variant="outline" onClick={() => setMessageDialog(true)}>
              <Send className="mr-2 h-4 w-4" />
              Отправить сообщение
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Stores */}
      <div>
        <h3 className="font-semibold mb-3 flex items-center gap-2">
          <Store className="h-4 w-4" />
          Магазины ({stores.length})
        </h3>
        {stores.length === 0 ? (
          <p className="text-muted-foreground text-sm">Нет магазинов</p>
        ) : (
          <div className="grid grid-cols-2 gap-3">
            {stores.map((store) => (
              <Card
                key={store.id}
                className="cursor-pointer hover:border-blue-300 transition-colors"
                onClick={() => router.push(`/stores/${store.id}`)}
              >
                <CardContent className="pt-4">
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="font-medium">{store.name}</p>
                      {store.category && (
                        <p className="text-sm text-muted-foreground">
                          {store.category}
                        </p>
                      )}
                    </div>
                    <Badge
                      variant="outline"
                      className={
                        !store.isActive
                          ? 'text-red-700 border-red-300'
                          : store.subscription?.status === 'ACTIVE'
                          ? 'text-green-700 border-green-300'
                          : store.subscription?.status === 'TRIAL'
                          ? 'text-blue-700 border-blue-300'
                          : 'text-yellow-700 border-yellow-300'
                      }
                    >
                      {store.subscription?.plan || store.subscription?.status || (store.isActive ? '—' : 'Приостановлен')}
                    </Badge>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>

      <Dialog open={messageDialog} onOpenChange={setMessageDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Отправить сообщение пользователю</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Заголовок</Label>
              <Input value={msgTitle} onChange={(e) => setMsgTitle(e.target.value)} maxLength={200} />
            </div>
            <div className="space-y-2">
              <Label>Текст</Label>
              <Textarea value={msgBody} onChange={(e) => setMsgBody(e.target.value)} rows={4} maxLength={1000} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMessageDialog(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => sendMessageMutation.mutate()}
              disabled={!msgTitle.trim() || !msgBody.trim() || sendMessageMutation.isPending}
            >
              <Send className="mr-2 h-4 w-4" />
              Отправить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
