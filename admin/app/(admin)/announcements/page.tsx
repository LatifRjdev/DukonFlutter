'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Send } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { api } from '@/lib/api';
import { Announcement } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

export default function AnnouncementsPage() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [targetPlan, setTargetPlan] = useState('all');
  const [targetStatus, setTargetStatus] = useState('all');
  const [confirmDialog, setConfirmDialog] = useState(false);
  const [recipientCount, setRecipientCount] = useState<number | null>(null);

  const { data: announcements = [], isLoading } = useQuery<Announcement[]>({
    queryKey: ['announcements'],
    queryFn: () => api.get('/admin/announcements').then((r) => r.data ?? []),
  });

  const previewMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/announcements/preview', {
        targetPlan: targetPlan === 'all' ? undefined : targetPlan,
        targetStatus: targetStatus === 'all' ? undefined : targetStatus,
      }),
    onSuccess: (data) => {
      setRecipientCount(data.count);
      setConfirmDialog(true);
    },
    onError: () => toast.error('Ошибка получения количества получателей'),
  });

  const sendMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/announcements', {
        title,
        body,
        targetPlan: targetPlan === 'all' ? undefined : targetPlan,
        targetStatus: targetStatus === 'all' ? undefined : targetStatus,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['announcements'] });
      setConfirmDialog(false);
      setTitle('');
      setBody('');
      setTargetPlan('all');
      setTargetStatus('all');
      setRecipientCount(null);
      toast.success('Объявление отправлено');
    },
    onError: () => toast.error('Ошибка отправки объявления'),
  });

  const handleSend = () => {
    if (!title.trim() || !body.trim()) {
      toast.error('Заполните заголовок и текст объявления');
      return;
    }
    previewMutation.mutate();
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Объявления</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Отправка уведомлений пользователям
        </p>
      </div>

      {/* Compose Form */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Новое объявление</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>Заголовок</Label>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Например: Новые функции в PREMIUM"
              maxLength={200}
            />
          </div>

          <div className="space-y-2">
            <Label>Текст объявления</Label>
            <Textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Введите текст объявления..."
              rows={4}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Фильтр по тарифу</Label>
              <Select value={targetPlan} onValueChange={(v) => v != null && setTargetPlan(v)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все тарифы</SelectItem>
                  <SelectItem value="START">START</SelectItem>
                  <SelectItem value="BUSINESS">BUSINESS</SelectItem>
                  <SelectItem value="PREMIUM">PREMIUM</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Фильтр по статусу</Label>
              <Select value={targetStatus} onValueChange={(v) => v != null && setTargetStatus(v)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все статусы</SelectItem>
                  <SelectItem value="active">Активные</SelectItem>
                  <SelectItem value="trial">Trial</SelectItem>
                  <SelectItem value="expired">Истекшие</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <Button
            onClick={handleSend}
            disabled={!title.trim() || !body.trim() || previewMutation.isPending}
          >
            <Send className="mr-2 h-4 w-4" />
            Отправить
          </Button>
        </CardContent>
      </Card>

      {/* History */}
      <div>
        <h2 className="font-semibold mb-3">История объявлений</h2>
        <div className="rounded-md border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Заголовок</TableHead>
                <TableHead>Аудитория</TableHead>
                <TableHead>Получателей</TableHead>
                <TableHead>Отправлено</TableHead>
                <TableHead>Отправитель</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 5 }).map((__, j) => (
                      <TableCell key={j}>
                        <div className="h-4 animate-pulse rounded bg-slate-100" />
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              ) : announcements.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="h-24 text-center text-muted-foreground"
                  >
                    Нет объявлений
                  </TableCell>
                </TableRow>
              ) : (
                announcements.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="font-medium max-w-xs truncate">
                      {a.title}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1 flex-wrap">
                        {a.targetPlan && (
                          <Badge variant="outline" className="text-xs">
                            {a.targetPlan}
                          </Badge>
                        )}
                        {a.targetStatus && (
                          <Badge variant="outline" className="text-xs">
                            {a.targetStatus}
                          </Badge>
                        )}
                        {!a.targetPlan && !a.targetStatus && (
                          <span className="text-sm text-muted-foreground">Все</span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>{a.recipientCount}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {a.sentAt ? format(new Date(a.sentAt), 'dd.MM.yyyy HH:mm') : '—'}
                    </TableCell>
                    <TableCell className="text-sm">{a.sentBy}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      {/* Confirm Dialog */}
      <Dialog open={confirmDialog} onOpenChange={setConfirmDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Подтверждение отправки</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm">
              Вы собираетесь отправить объявление{' '}
              <strong>{recipientCount ?? '?'}</strong> получателям.
            </p>
            <div className="rounded-md bg-slate-50 p-3 space-y-1">
              <p className="font-medium text-sm">{title}</p>
              <p className="text-sm text-muted-foreground line-clamp-3">{body}</p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmDialog(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => sendMutation.mutate()}
              disabled={sendMutation.isPending}
            >
              <Send className="mr-2 h-4 w-4" />
              Подтвердить и отправить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
