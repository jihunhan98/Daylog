package com.daylog.user.repository;

import com.daylog.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByPhone(String phone);

    boolean existsByCoupleCode(String coupleCode);

    Optional<User> findByCoupleCode(String coupleCode);
}