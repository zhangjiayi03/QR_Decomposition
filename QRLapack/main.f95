program main
    implicit none
    ! Variables
    integer, parameter :: n = 2048
    integer*4 :: k, siz
    real*8 :: A(n, n), Q(n, n), R(n, n), P(n, n), vT(n, 1), vrT(n, 1), vq(n, 1)
    real*8 :: w1, w2
    real*8 :: error_of_qr
    real*8 :: newA(n, n)
    !real*8 :: QQT(n, n)
    real :: start, finish
	real*8 :: tau(n)
    real*8, allocatable :: work(:)
    integer*4 :: lwork, info
	! Функции
    real*8 :: dnrm2, ddot
	
    ! Program

    call RANDOM_NUMBER(A)
    !call create_bad_matrix(n, 20, A)

    call create_I(n, Q)
    R = A
   
    call cpu_time(start)
    ! A = Q*R
	! P = I - (2/vT*v) * v*vT - householder matrix, v - householder
    ! Pn*Pn-1*...*P1*A = R
    ! P1*P2*...*Pn = Q
    do k = 1, n
        ! Compute Rn = Pn * Rn-1 and Qn = Qn-1 * PnT

        ! Set size our vectors
        siz = n - k + 1

        ! Compute Householder vector vT
        vT(1 : siz, 1) = R(k : k + siz - 1, k)

        w1 = dnrm2(siz, vT, 1)

        if (R(k, k) > 0) then
            vT(1, 1) = vT(1, 1) + w1
        else
            vT(1, 1) = vT(1, 1) - w1
        endif

		! Compute vrT = vT * R and compute w2 = (v, v)      
        call dgemv('T', siz, siz, 1d0, R(k, k), n, vT, 1, 0d0, vrT, 1)
        w2 = ddot(siz, vT, 1, vT, 1)

		!Compute vq = Q * v
        call dgemv('N', n, siz, 1d0, Q(1, k), n, vT, 1, 0d0, vq, 1)

        ! Compute w2 = 2/(v, v)
        w2 = 2.0 / w2
		
		! Compute new R = R - w2(v * vrT)
        call dgemm('N', 'T', siz, siz, 1, -w2, vT, n, vrT, n, 1d0, R(k, k), n)
		
		! Compute new Q = Q - w2(vq * vT)
        call dgemm('N', 'T', n, siz, 1, -w2, vq, n, vT, n, 1d0, Q(1, k), n)

    enddo
    call cpu_time(finish)
    print *, finish - start

    !QQT = MATMUL(Q, TRANSPOSE(Q))
    newA = MATMUL(Q, R)

    print *, error_of_qr(A, newA, n)

	! Lapack code
	call cpu_time(start)
	allocate(work(1))
    call dgeqrf(n, n, A, n, tau, work, -1, info)
    lwork = work(1)
    deallocate(work)
    allocate(work(lwork))
    call dgeqrf(n, n, A, n, tau, work, lwork, info)
    !print *, lwork
	call cpu_time(finish)
    print *, finish - start

end

subroutine create_I(n, A)
    implicit none
    ! Variables
    integer*4 n
    real*8 A(n, n)
    integer*4 i,j

    ! Function
    do j = 1, n
        do i = 1, n
            if (i == j) then
                A(i, i) = 1
            else
                A(i, j) = 0
            endif
        enddo
    enddo

    return
end

! Generate bad matrix Ak = H1 * diag(yk) * H2,
! where y1 / yn = 10**k and y1 > y2 ... yn-1 > yn,
! H1, H2 - Householder matrix
subroutine create_bad_matrix(n, k, A)
    implicit none
    ! Variables
    integer*4 :: n, k
    real*8 :: A(n, n)

    integer*4 :: i
    real*8 :: w1, w2
    real*8 :: v1(n, 1), v2(n, 1)
    real*8 :: v1T(1, n), v2T(1, n)

    real*8 :: H1(n, n), H2(n, n), Y(n, n)
    real*8 :: h, deg
    ! Function
    ! Generate random Householder vector v1 and v2 and compute w = (v,v)
    call RANDOM_NUMBER(v1)
    call RANDOM_NUMBER(v2)


    w1 = dot_product(v1(1 : n, 1), v1(1 : n, 1))
    w2 = dot_product(v2(1 : n, 1), v2(1 : n, 1))
    !w1 = 0
    !w2 = 0
    !do i = 1, n
    !    w1 = w1 + v1(i, 1)**2
    !    w2 = w2 + v2(i, 1)**2
    !enddo

    w1 = 2 / w1
    w2 = 2 / w2

    ! Create Householder matrix H1 and H2
    call create_I(n, H1)
    call create_I(n, H2)
    v1T = TRANSPOSE(v1) ! !!!
    v2T = TRANSPOSE(v2) ! !!!
    H1 = H1 - w1*MATMUL(v1, v1T)
    H2 = H2 - w2*MATMUL(v2, v2T)

    ! Create daig(yk)
    call create_I(n, Y)
    h = REAL(k, 8) / (n - 1)
    deg = 0
    do i = 1, n
        Y(n - i + 1, n - i + 1) = 10**deg
        deg = deg + h
    enddo

    ! Create Ak = H1 * Y * H2
    A = MATMUL(H1, MATMUL(Y, H2))

    return
end

real*8 function error_of_qr(A, newA, n)
    implicit none
    ! Variables
    integer, intent(in) :: n
    real*8 A(n, n), newA(n, n)
    real*8 norm
    integer*4 i, j
    ! Function
    error_of_qr = 0
    norm = 0
    do j = 1, n
        do i = 1, n
            error_of_qr = error_of_qr + (A(i, j) - newA(i, j))**2
            norm = norm + A(i, j)**2
        enddo
    enddo
    norm = sqrt(norm)
    error_of_qr = sqrt(error_of_qr) / norm
    return
end function
